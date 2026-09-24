import os
import sys
import json
from unittest.mock import patch, MagicMock

# Ensure Django is initialized when running standalone via unittest runner
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "vishleshan_backend.settings")

import django
from django.apps import apps
if not apps.ready:
    django.setup()

from django.test import TestCase
from django.urls import reverse
from django.core.cache import cache
from api.services import twofactor_service

class TwoFactorTest(TestCase):
    def setUp(self):
        cache.clear()
        self.original_key = os.environ.get("TWOFACTOR_API_KEY")
        self.dummy_key = "4f991880-8339-11f1-9728-0200cd936042"
        os.environ["TWOFACTOR_API_KEY"] = self.dummy_key
        twofactor_service.TWOFACTOR_API_KEY = self.dummy_key

    def tearDown(self):
        cache.clear()
        if self.original_key is not None:
            os.environ["TWOFACTOR_API_KEY"] = self.original_key
            twofactor_service.TWOFACTOR_API_KEY = self.original_key
        else:
            os.environ.pop("TWOFACTOR_API_KEY", None)
            twofactor_service.TWOFACTOR_API_KEY = None

    @patch("httpx.get")
    def test_send_otp_success(self, mock_get):
        # Successful API response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "Status": "Success",
            "Details": "session-12345"
        }
        mock_get.return_value = mock_response

        res = twofactor_service.send_otp("+918849538117")
        self.assertTrue(res["success"])
        self.assertEqual(res["session_id"], "session-12345")
        self.assertIsNone(res["error"])

    @patch("httpx.get")
    def test_send_voice_otp_success(self, mock_get):
        # Successful API response for voice call
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "Status": "Success",
            "Details": "voice-session-abc"
        }
        mock_get.return_value = mock_response

        res = twofactor_service.send_otp("+918849538117", method="voice")
        self.assertTrue(res["success"])
        self.assertEqual(res["session_id"], "voice-session-abc")
        self.assertIsNone(res["error"])
        # Ensure it called the voice URL structure
        args, kwargs = mock_get.call_args
        self.assertIn("/VOICE/", args[0])

    @patch("httpx.get")
    def test_verify_otp_success(self, mock_get):
        # Successful Verification response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "Status": "Success",
            "Details": "OTP Matched"
        }
        mock_get.return_value = mock_response

        res = twofactor_service.verify_otp("session-12345", "123456")
        self.assertTrue(res["success"])
        self.assertIsNone(res["error"])

    @patch("httpx.get")
    def test_verify_otp_wrong_code(self, mock_get):
        # Failed verification due to wrong code
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "Status": "Error",
            "Details": "OTP Mismatch"
        }
        mock_get.return_value = mock_response

        res = twofactor_service.verify_otp("session-12345", "111111")
        self.assertFalse(res["success"])
        self.assertEqual(res["error"], "OTP Mismatch")

    @patch("httpx.get")
    def test_verify_otp_expired_session(self, mock_get):
        # Failed verification due to expired session
        mock_response = MagicMock()
        mock_response.status_code = 400
        mock_response.json.return_value = {
            "Status": "Error",
            "Details": "Invalid API / SessionId Combination - No Entry Exists"
        }
        mock_get.return_value = mock_response

        res = twofactor_service.verify_otp("expired-session-id", "123456")
        self.assertFalse(res["success"])
        self.assertEqual(res["error"], "Invalid API / SessionId Combination - No Entry Exists")

    @patch("httpx.get")
    def test_send_otp_api_failure_fallback_triggered(self, mock_get):
        # Mock API failure (non-200 response)
        mock_response = MagicMock()
        mock_response.status_code = 500
        mock_response.text = "Internal Server Error"
        mock_get.return_value = mock_response

        # POST request to send_phone_otp view
        url = reverse("verification-send-phone-otp")
        data = {
            "phone": "+918849538117",
            "role": "seeker",
            "email": "dakshbhavsar2712@gmail.com"
        }
        response = self.client.post(
            url,
            data=json.dumps(data),
            content_type="application/json"
        )
        self.assertEqual(response.status_code, 200)
        res_json = response.json()
        self.assertTrue(res_json["success"])
        self.assertIn("Simulated OTP", res_json["data"]["message"])
