from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
def health() -> dict[str, str]:
    # Simple health probe for backend availability
    return {"status": "ok"}
