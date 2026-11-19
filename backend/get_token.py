import requests
from firebase_admin import auth, credentials, initialize_app

WEB_API_KEY = "AIzaSyDyhobz2c8IihA7SceYo2Hwabg8yKI63s4"
TEST_UID = "mock_uid_user_02"  

cred = credentials.Certificate("serviceAccountKey.json")
initialize_app(cred)

# 1. Tạo Custom Token từ Admin SDK
custom_token = auth.create_custom_token(TEST_UID).decode("utf-8")

# 2. Đổi Custom Token lấy ID Token (Bearer Token chuẩn)
url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key={WEB_API_KEY}"
res = requests.post(url, json={"token": custom_token, "returnSecureToken": True}).json()

print("\n=== COPY TOKEN BÊN DƯỚI DÁN VÀO SWAGGER ===\n")
print(res["idToken"])
print("\n==========================================\n")