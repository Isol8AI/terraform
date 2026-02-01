"""
Lambda authorizer for WebSocket API Gateway.

Validates Clerk JWT tokens passed via query parameter on WebSocket $connect.
Returns authorization context (user_id, org_id) for API Gateway to forward to backend.
"""

import os
import logging
from typing import Any

import jwt
from jwt import PyJWKClient

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Clerk configuration from environment
CLERK_JWKS_URL = os.environ.get("CLERK_JWKS_URL", "")
CLERK_ISSUER = os.environ.get("CLERK_ISSUER", "")

# Cache JWKS client (reused across invocations)
_jwks_client = None


def get_jwks_client() -> PyJWKClient:
    """Get or create cached JWKS client."""
    global _jwks_client
    if _jwks_client is None:
        if not CLERK_JWKS_URL:
            raise ValueError("CLERK_JWKS_URL environment variable not set")
        _jwks_client = PyJWKClient(CLERK_JWKS_URL, cache_keys=True)
    return _jwks_client


def handler(event: dict, context: Any) -> dict:
    """
    Lambda authorizer handler for WebSocket API.

    Args:
        event: API Gateway authorizer event containing:
            - queryStringParameters: {token: "jwt..."}
            - methodArn: Resource ARN for policy
        context: Lambda context (unused)

    Returns:
        Authorization response with:
            - isAuthorized: bool
            - context: {userId, orgId} if authorized
    """
    logger.info("Authorizer invoked")

    # Extract token from query parameters
    query_params = event.get("queryStringParameters") or {}
    token = query_params.get("token")

    if not token:
        logger.warning("No token provided in query parameters")
        return {"isAuthorized": False}

    try:
        # Get signing key from JWKS
        jwks_client = get_jwks_client()
        signing_key = jwks_client.get_signing_key_from_jwt(token)

        # Decode and validate JWT
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            issuer=CLERK_ISSUER,
            options={
                "verify_exp": True,
                "verify_iss": True,
                "verify_aud": False,  # Clerk doesn't use audience
            }
        )

        # Extract user and org info
        user_id = payload.get("sub")
        org_id = payload.get("org_id")  # Present if user is in org context

        if not user_id:
            logger.warning("Token missing 'sub' claim")
            return {"isAuthorized": False}

        logger.info(f"Authorized user_id={user_id}, org_id={org_id or 'personal'}")

        return {
            "isAuthorized": True,
            "context": {
                "userId": user_id,
                "orgId": org_id or "",
            }
        }

    except jwt.ExpiredSignatureError:
        logger.warning("Token expired")
        return {"isAuthorized": False}
    except jwt.InvalidIssuerError:
        logger.warning("Invalid token issuer")
        return {"isAuthorized": False}
    except jwt.InvalidTokenError as e:
        logger.warning(f"Invalid token: {e}")
        return {"isAuthorized": False}
    except Exception as e:
        logger.exception(f"Unexpected error validating token: {e}")
        return {"isAuthorized": False}
