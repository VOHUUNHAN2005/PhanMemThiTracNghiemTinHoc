import firebase_admin
from firebase_admin import auth, credentials
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from database import get_db
from sqlalchemy import text
from sqlalchemy.orm import Session

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

app = FastAPI(title="IT Quiz App API")
security = HTTPBearer()


def verify_firebase_token(
    res: HTTPAuthorizationCredentials = Depends(security),
):
    token = res.credentials
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token không hợp lệ hoặc đã hết hạn.",
        )


@app.get("/")
def health_check():
    return {"status": "ok", "message": "IT Quiz Backend đang hoạt động!"}


@app.get("/api/me")
def get_current_user(user_data: dict = Depends(verify_firebase_token)):
    return {
        "uid": user_data.get("uid"),
        "email": user_data.get("email"),
        "message": "Xác thực Firebase thành công!aaaaa",
    }
@app.get("/api/chu-de")
def get_danh_sach_chu_de(db: Session = Depends(get_db)):
    result = db.execute(text("SELECT MaChuDe, TenChuDe, MoTa FROM ChuDe")).mappings().all()
    return {"data": list(result)}