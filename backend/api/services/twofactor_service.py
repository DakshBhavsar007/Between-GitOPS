"""
2Factor SMS Service Wrapper
───────────────────────────
Provides integration with 2Factor's SMS OTP Gateway.
"""

import os
import logging
import httpx

logger = logging.getLogger(__name__)

# Load API key from environment
TWOFACTOR_API_KEY = os.getenv("TWOFACTOR_API_KEY")

def mask_phone(phone: str) -> str:
    """
    Mask phone number for logging privacy (e.g. ******8117)
    """
    cleaned = "".join(filter(str.isdigit, phone))
    if len(cleaned) > 4:
        return "*" * (len(cleaned) - 4) + cleaned[-4:]
    return cleaned

def clean_phone_for_2factor(phone: str) -> str:
    """
    Format phone number as 91XXXXXXXXXX (without leading + or spaces)
    """
    cleaned = "".join(filter(str.isdigit, phone))
    if len(cleaned) == 10:
        cleaned = "91" + cleaned
    return cleaned

def send_otp(phone_number: str, method: str = "sms") -> dict:
    """
    Send OTP via 2Factor.in SMS Gateway using AUTOGEN3 (SMS) or VOICE (Call) route.
    
    Parameters
    ----------
    phone_number : str
        Recipient phone number
    method : str, optional
        The transmission method, either 'sms' or 'voice'. Defaults to 'sms'.
        
    Returns
    -------
    dict
        {"success": bool, "session_id": str, "error": str or None}
    """
    masked = mask_phone(phone_number)
    api_key = os.getenv("TWOFACTOR_API_KEY") or TWOFACTOR_API_KEY
    if not api_key:
        logger.warning("TWOFACTOR_API_KEY is not set in environment variables.")
        return {
            "success": False,
            "session_id": "",
            "error": "2Factor API Key not configured."
        }

    phone = clean_phone_for_2factor(phone_number)
    
    if method == "voice":
        url = f"https://2factor.in/API/V1/{api_key}/VOICE/{phone}/AUTOGEN"
    else:
        url = f"https://2factor.in/API/V1/{api_key}/SMS/{phone}/AUTOGEN"
    
    logger.info("Attempting to send 2Factor OTP via %s to %s...", method.upper(), masked)
    try:
        response = httpx.get(url, timeout=10.0)
        if response.status_code == 200:
            res_data = response.json()
            if res_data.get("Status") == "Success":
                session_id = res_data.get("Details")
                logger.info("2Factor OTP sent successfully via %s to %s. Session ID: %s", method.upper(), masked, session_id)
                return {
                    "success": True,
                    "session_id": session_id,
                    "error": None
                }
            else:
                err_msg = res_data.get("Details", "Unknown 2Factor error")
                logger.error("2Factor API returned error for %s: %s", masked, err_msg)
                return {
                    "success": False,
                    "session_id": "",
                    "error": err_msg
                }
        else:
            logger.error("2Factor API failed for %s with status code %d: %s", masked, response.status_code, response.text)
            return {
                "success": False,
                "session_id": "",
                "error": f"2Factor API returned status code {response.status_code}"
            }
    except Exception as e:
        logger.error("Network or parsing error while sending 2Factor OTP to %s: %s", masked, e)
        return {
            "success": False,
            "session_id": "",
            "error": str(e)
        }

def verify_otp(session_id: str, otp_code: str) -> dict:
    """
    Verify OTP using 2Factor VERIFY endpoint.
    
    Parameters
    ----------
    session_id : str
        The OTP session ID returned by send_otp
    otp_code : str
        The OTP code submitted by the user
        
    Returns
    -------
    dict
        {"success": bool, "error": str or None}
    """
    api_key = os.getenv("TWOFACTOR_API_KEY") or TWOFACTOR_API_KEY
    if not api_key:
        return {
            "success": False,
            "error": "2Factor API Key not configured."
        }

    if not session_id:
        return {
            "success": False,
            "error": "Missing session ID. Please request a new verification code."
        }

    url = f"https://2factor.in/API/V1/{api_key}/SMS/VERIFY/{session_id}/{otp_code.strip()}"
    
    logger.info("Verifying 2Factor OTP for session %s...", session_id)
    try:
        response = httpx.get(url, timeout=10.0)
        if response.status_code == 200:
            res_data = response.json()
            details = res_data.get("Details", "")
            # Check for success
            if res_data.get("Status") == "Success" or "Matched" in details:
                logger.info("2Factor OTP verification successful for session %s", session_id)
                return {
                    "success": True,
                    "error": None
                }
            else:
                # Handle expired session or wrong OTP details
                logger.warning("2Factor OTP verification failed for session %s: %s", session_id, details)
                return {
                    "success": False,
                    "error": details or "Invalid OTP"
                }
        else:
            try:
                err_msg = response.json().get("Details", "Verification failed")
            except Exception:
                err_msg = response.text
            logger.error("2Factor OTP verification request failed with status %d: %s", response.status_code, err_msg)
            return {
                "success": False,
                "error": err_msg
            }
    except Exception as e:
        logger.error("Error during 2Factor OTP verification: %s", e)
        return {
            "success": False,
            "error": str(e)
        }
