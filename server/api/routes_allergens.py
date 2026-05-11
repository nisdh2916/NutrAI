from fastapi import APIRouter
from ai.allergens import ALLERGEN_KEYWORDS, ALLERGEN_CATEGORIES

router = APIRouter(prefix="/allergens", tags=["allergens"])


@router.get("")
def get_allergens():
    """알레르겐 카테고리 목록 및 키워드 매핑 반환."""
    return {
        "categories": ALLERGEN_CATEGORIES,
        "keywords": ALLERGEN_KEYWORDS,
    }
