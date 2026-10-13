from pydantic import BaseModel, EmailStr, Field, field_validator

from app.schemas.user import UserOut


def _check_password_strength(value: str) -> str:
    if not any(c.isalpha() for c in value) or not any(c.isdigit() for c in value):
        raise ValueError("Password must contain at least one letter and one number")
    return value


PasswordField = Field(min_length=8, max_length=128)


class RegisterIn(BaseModel):
    email: EmailStr
    password: str = PasswordField
    full_name: str = Field(default="", max_length=100)

    _strength = field_validator("password")(_check_password_strength)


class LoginIn(BaseModel):
    email: EmailStr
    password: str = Field(max_length=128)


class GoogleLoginIn(BaseModel):
    id_token: str = Field(min_length=20, max_length=4096)


class RefreshIn(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=256)


class TokenIn(BaseModel):
    token: str = Field(min_length=20, max_length=256)


class ForgotPasswordIn(BaseModel):
    email: EmailStr


class ResetPasswordIn(BaseModel):
    token: str = Field(min_length=20, max_length=256)
    new_password: str = PasswordField

    _strength = field_validator("new_password")(_check_password_strength)


class ChangePasswordIn(BaseModel):
    # Optional for Google-only accounts that have no password yet.
    current_password: str | None = Field(default=None, max_length=128)
    new_password: str = PasswordField

    _strength = field_validator("new_password")(_check_password_strength)


class AuthOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserOut


class MessageOut(BaseModel):
    message: str
