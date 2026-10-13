from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse


class AppError(Exception):
    """Domain error with a user-friendly message, rendered as {"detail": message}."""

    status_code = status.HTTP_400_BAD_REQUEST

    def __init__(self, message: str, status_code: int | None = None) -> None:
        super().__init__(message)
        self.message = message
        if status_code is not None:
            self.status_code = status_code


class AuthError(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED


class ConflictError(AppError):
    status_code = status.HTTP_409_CONFLICT


class NotFoundError(AppError):
    status_code = status.HTTP_404_NOT_FOUND


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _handle_app_error(_: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(status_code=exc.status_code, content={"detail": exc.message})
