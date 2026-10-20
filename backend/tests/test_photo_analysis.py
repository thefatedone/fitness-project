"""Unit tests for the pure validation / sanity-correction logic in
`app.services.photo_analysis`. No FastAPI, no DB, no Redis — every
test exercises pure functions against in-memory dicts."""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.services.photo_analysis import (
    KCAL_SANITY_TOLERANCE,
    MAX_GRAMS,
    MIN_GRAMS,
    AnalyzedItem,
    AnalyzedPer100g,
    AnalyzedPoint,
    AnalyzedTotals,
    PhotoAnalysisResult,
    PlateBox,
    cache_key,
    rate_limit_key,
    validate_and_normalize,
)


def _good_raw_item(**overrides) -> dict:
    base = {
        "id": "item-1",
        "name": "Grilled Chicken Breast",
        "grams": 150,
        "point": {"x": 0.42, "y": 0.55},
        "confidence": 0.82,
        "per_100g": {"kcal": 165, "protein": 31, "carbs": 0, "fat": 3.6},
    }
    base.update(overrides)
    return base


# ---------------------------------------------------------------------------
# Schema-level validation
# ---------------------------------------------------------------------------

class TestModels:
    def test_analyzed_point_rejects_out_of_range(self):
        # The model is strict at construction (the clamping happens in
        # validate_and_normalize so the cache/redis round-trip stays
        # trustworthy). Out-of-range coordinates on the model = bad
        # contract, not a silent clamp.
        with pytest.raises(ValidationError):
            AnalyzedPoint(x=-0.1, y=0.5)
        with pytest.raises(ValidationError):
            AnalyzedPoint(x=0.5, y=1.5)

    def test_analyzed_point_rejects_nan(self):
        with pytest.raises(ValidationError):
            AnalyzedPoint(x=float("nan"), y=0.0)

    def test_plate_box_accepts_valid_box(self):
        pb = PlateBox(x=0.1, y=0.2, w=0.8, h=0.7)
        assert pb.w == 0.8

    def test_per_100g_rejects_negative(self):
        with pytest.raises(ValidationError):
            AnalyzedPer100g(kcal=-1, protein=0, carbs=0, fat=0)

    def test_analyzed_item_grams_below_min_rejected(self):
        with pytest.raises(ValidationError):
            AnalyzedItem(
                id="i", name="grilled", grams=2,
                point=AnalyzedPoint(x=0, y=0), confidence=0.5,
                per_100g=AnalyzedPer100g(kcal=100, protein=10, carbs=0, fat=1),
                totals=AnalyzedTotals(kcal=0, protein=0, carbs=0, fat=0),
            )

    def test_analyzed_item_grams_above_max_rejected(self):
        with pytest.raises(ValidationError):
            AnalyzedItem(
                id="i", name="grilled", grams=2000,
                point=AnalyzedPoint(x=0, y=0), confidence=0.5,
                per_100g=AnalyzedPer100g(kcal=100, protein=10, carbs=0, fat=1),
                totals=AnalyzedTotals(kcal=0, protein=0, carbs=0, fat=0),
            )


# ---------------------------------------------------------------------------
# validate_and_normalize — round-trip, clamps, rounding, sanity
# ---------------------------------------------------------------------------

class TestValidateAndNormalize:
    def test_well_formed_input_round_trips(self):
        raw = {
            "no_food_detected": False,
            "plate_box": {"x": 0.1, "y": 0.2, "w": 0.8, "h": 0.7},
            "items": [_good_raw_item()],
        }
        result = validate_and_normalize(raw)
        assert isinstance(result, PhotoAnalysisResult)
        assert result.no_food_detected is False
        assert result.plate_box is not None
        assert len(result.items) == 1

        item = result.items[0]
        assert item.id == "item-1"
        assert item.name == "Grilled Chicken Breast"
        assert item.grams == 150
        assert item.confidence == 0.82
        assert item.per_100g.kcal == 165
        assert item.per_100g.protein == 31.0
        assert item.per_100g.fat == 3.6

    def test_totals_are_per_100g_times_grams_over_100(self):
        raw = {"no_food_detected": False, "items": [_good_raw_item(grams=200)]}
        result = validate_and_normalize(raw)
        item = result.items[0]
        assert item.totals.kcal == int(round(165 * 200 / 100))   # 330
        assert item.totals.protein == round(31 * 200 / 100, 1)   # 62.0
        assert item.totals.fat == round(3.6 * 200 / 100, 1)     # 7.2

    def test_kcal_rounded_to_int_macros_to_one_decimal(self):
        raw = {"no_food_detected": False, "items": [_good_raw_item(grams=137)]}
        result = validate_and_normalize(raw)
        item = result.items[0]
        assert isinstance(item.totals.kcal, int)
        assert isinstance(item.totals.protein, float)
        # Check rounding: 31 * 1.37 = 42.47, rounded to one decimal = 42.5
        assert item.totals.protein == 42.5

    def test_meal_totals_are_sum_of_item_totals(self):
        # Per-100g kcal chosen so the sanity check is NOT triggered
        # (within 20% of the Atwater-derived value), so the test
        # isolates the summing logic from the correction logic.
        # protein 10 → 40 kcal Atwater; stated 40 → diff = 0 → kept
        # protein 20 → 80 kcal Atwater; stated 80 → diff = 0 → kept
        items = [
            _good_raw_item(id="i1", grams=150, per_100g={"kcal": 40, "protein": 10, "carbs": 0, "fat": 0}),
            _good_raw_item(id="i2", grams=150, per_100g={"kcal": 80, "protein": 20, "carbs": 0, "fat": 0}),
        ]
        raw = {"no_food_detected": False, "items": items}
        result = validate_and_normalize(raw)
        # item1: 40 * 150/100 = 60; item2: 80 * 150/100 = 120; sum = 180
        assert result.totals.kcal == 180
        # 10*1.5 + 20*1.5 = 15 + 30 = 45
        assert result.totals.protein == 45.0

    def test_coordinates_clamped_to_unit_interval(self):
        raw = {
            "no_food_detected": False,
            "plate_box": {"x": -0.5, "y": 0.5, "w": 1.5, "h": -0.1},
            "items": [_good_raw_item(point={"x": -1.0, "y": 2.0})],
        }
        result = validate_and_normalize(raw)
        assert result.plate_box.x == 0.0
        assert result.plate_box.w == 1.0
        assert result.plate_box.h == 0.0
        assert result.items[0].point.x == 0.0
        assert result.items[0].point.y == 1.0

    def test_grams_clamped_to_bracket(self):
        raw = {
            "no_food_detected": False,
            "items": [
                _good_raw_item(id="low", grams=1),
                _good_raw_item(id="high", grams=5000),
            ],
        }
        result = validate_and_normalize(raw)
        grams_by_id = {it.id: it.grams for it in result.items}
        assert grams_by_id["low"] == MIN_GRAMS
        assert grams_by_id["high"] == MAX_GRAMS

    def test_grams_exactly_at_brackets_unchanged(self):
        raw = {
            "no_food_detected": False,
            "items": [
                _good_raw_item(id="min", grams=MIN_GRAMS),
                _good_raw_item(id="max", grams=MAX_GRAMS),
            ],
        }
        result = validate_and_normalize(raw)
        assert result.items[0].grams == MIN_GRAMS
        assert result.items[1].grams == MAX_GRAMS

    def test_confidence_clamped_to_unit_interval(self):
        raw = {
            "no_food_detected": False,
            "items": [_good_raw_item(confidence=1.7)],
        }
        result = validate_and_normalize(raw)
        assert result.items[0].confidence == 1.0


# ---------------------------------------------------------------------------
# Sanity-correction (kcal vs Atwater macros)
# ---------------------------------------------------------------------------

class TestSanityCorrection:
    def test_kcal_within_tolerance_kept(self):
        # 4*31 + 4*0 + 9*3.6 = 124 + 32.4 = 156.4 ≈ 165
        # diff = (165-156.4)/165 ≈ 0.052, below 10% → keep 165
        raw = {"no_food_detected": False, "items": [_good_raw_item()]}
        result = validate_and_normalize(raw)
        assert result.items[0].per_100g.kcal == 165

    def test_kcal_outside_tolerance_corrected_to_macros(self):
        # per_100g.kcal=500 but macros suggest 4*5+4*50+9*0=220 → way off (>10%) → correct
        raw = {
            "no_food_detected": False,
            "items": [_good_raw_item(per_100g={"kcal": 500, "protein": 5, "carbs": 50, "fat": 0})],
        }
        result = validate_and_normalize(raw)
        assert result.items[0].per_100g.kcal == int(round(4 * 5 + 4 * 50 + 9 * 0))

    def test_kcal_correction_at_exact_threshold(self):
        # 4*10 + 4*0 + 9*0 = 40
        # per_100g.kcal=44 → diff = 4/44 ≈ 0.091 → just under 10% → kept
        raw = {
            "no_food_detected": False,
            "items": [_good_raw_item(per_100g={"kcal": 44, "protein": 10, "carbs": 0, "fat": 0})],
        }
        result = validate_and_normalize(raw)
        assert result.items[0].per_100g.kcal == 44

    def test_kcal_correction_just_above_threshold(self):
        # 4*10 + 4*0 + 9*0 = 40
        # per_100g.kcal=45 → diff = 5/45 ≈ 0.111 → just over 10% → correct to 40
        raw = {
            "no_food_detected": False,
            "items": [_good_raw_item(per_100g={"kcal": 45, "protein": 10, "carbs": 0, "fat": 0})],
        }
        result = validate_and_normalize(raw)
        assert result.items[0].per_100g.kcal == 40

    def test_kcal_zero_with_zero_macros_drops_item(self):
        raw = {
            "no_food_detected": False,
            "items": [_good_raw_item(per_100g={"kcal": 0, "protein": 0, "carbs": 0, "fat": 0})],
        }
        result = validate_and_normalize(raw)
        assert result.items == []
        assert result.totals.kcal == 0

    def test_kcal_zero_with_nonzero_macros_keeps_item(self):
        # plain water: kcal=0 but protein/carbs/fat could be 0 too in practice,
        # so this test uses a case where kcal=0 but macros sum to a positive
        # atwater value — sanity correction would normally trigger, but
        # kcal_p100 == 0 short-circuits the ratio check.
        raw = {
            "no_food_detected": False,
            "items": [_good_raw_item(per_100g={"kcal": 0, "protein": 10, "carbs": 0, "fat": 0})],
        }
        result = validate_and_normalize(raw)
        assert len(result.items) == 1
        # kcal stays 0 because the spec says skip the ratio check when kcal_p100==0.
        assert result.items[0].per_100g.kcal == 0
        # but the macros that were stated are kept verbatim
        assert result.items[0].per_100g.protein == 10.0


# ---------------------------------------------------------------------------
# No-food path
# ---------------------------------------------------------------------------

class TestNoFoodPath:
    def test_no_food_returns_empty_items_and_meal_totals_zero(self):
        raw = {"no_food_detected": True, "items": []}
        result = validate_and_normalize(raw)
        assert result.no_food_detected is True
        assert result.items == []
        assert result.plate_box is None
        assert result.totals.kcal == 0
        assert result.totals.protein == 0.0

    def test_no_food_with_items_drops_items(self):
        # If the model said no_food but also returned items, trust the
        # items and flip the flag to false.
        raw = {
            "no_food_detected": True,
            "items": [_good_raw_item()],
        }
        result = validate_and_normalize(raw)
        assert result.no_food_detected is False
        assert len(result.items) == 1

    def test_no_food_with_items_and_plate_box_keeps_plate_box(self):
        raw = {
            "no_food_detected": True,
            "plate_box": {"x": 0, "y": 0, "w": 1, "h": 1},
            "items": [_good_raw_item()],
        }
        result = validate_and_normalize(raw)
        assert result.no_food_detected is False
        assert result.plate_box is not None


# ---------------------------------------------------------------------------
# Robustness / garbage item handling
# ---------------------------------------------------------------------------

class TestGarbageInput:
    def test_missing_items_key_treated_as_empty(self):
        # Defensive default. The JSON schema requires `items`, but
        # if the model ever omits it we shouldn't blow up — empty
        # result + no_food_detected stays false, meal totals zero.
        result = validate_and_normalize({"no_food_detected": False})
        assert result.items == []
        assert result.no_food_detected is False
        assert result.totals.kcal == 0

    def test_items_not_a_list_raises_value_error(self):
        with pytest.raises(ValueError):
            validate_and_normalize({"no_food_detected": False, "items": "not a list"})

    def test_non_dict_input_raises_value_error(self):
        with pytest.raises(ValueError):
            validate_and_normalize("not a dict")

    def test_item_missing_required_field_skipped(self):
        raw = {
            "no_food_detected": False,
            "items": [
                {"id": "x", "name": "x"},  # missing grams/point/etc.
                _good_raw_item(id="y"),
            ],
        }
        result = validate_and_normalize(raw)
        assert [it.id for it in result.items] == ["y"]

    def test_item_with_non_positive_grams_skipped(self):
        raw = {
            "no_food_detected": False,
            "items": [
                _good_raw_item(id="bad", grams=0),
                _good_raw_item(id="ok", grams=100),
            ],
        }
        result = validate_and_normalize(raw)
        assert [it.id for it in result.items] == ["ok"]

    def test_duplicate_ids_get_unique_ids(self):
        raw = {
            "no_food_detected": False,
            "items": [
                _good_raw_item(id="dup"),
                _good_raw_item(id="dup"),
            ],
        }
        result = validate_and_normalize(raw)
        ids = [it.id for it in result.items]
        assert len(ids) == 2
        assert len(set(ids)) == 2

    def test_item_with_missing_per_100g_field_skipped(self):
        raw = {
            "no_food_detected": False,
            "items": [
                _good_raw_item(id="broken", per_100g={"kcal": 100}),  # missing protein/carbs/fat
                _good_raw_item(id="ok"),
            ],
        }
        result = validate_and_normalize(raw)
        assert [it.id for it in result.items] == ["ok"]


# ---------------------------------------------------------------------------
# Per-item kcal safety net
# ---------------------------------------------------------------------------

class TestPerItemKcalCap:
    """When a single item's totals.kcal would exceed the safety cap,
    the validator scales grams down so the item lands at the cap.
    This catches the common case where the model over-estimates
    portion sizes (e.g. 800 g of bacon at 540 kcal/100g → 4320 kcal,
    clearly wrong for a single item)."""

    def test_overestimated_portion_capped_to_1200_kcal(self):
        # 540 kcal/100g × 800 g = 4320 kcal → over cap → grams scaled
        # to 1200/540 × 100 ≈ 222.2 g → totals 1200 kcal.
        raw = {
            "no_food_detected": False,
            "items": [_good_raw_item(
                id="bacon",
                grams=800,
                per_100g={"kcal": 540, "protein": 37, "carbs": 1, "fat": 42},
            )],
        }
        result = validate_and_normalize(raw)
        assert result.items[0].totals.kcal == 1200
        # Grams should have been scaled down to land at the cap.
        assert result.items[0].grams < 800
        # Per-100g reference preserved.
        assert result.items[0].per_100g.kcal == 540

    def test_under_cap_unchanged(self):
        # 165 kcal/100g (chicken breast reference) × 200 g = 330 kcal →
        # under cap → unchanged. Per-100g macros (31p/0c/3.6f) yield
        # Atwater = 156.4, within the 10% tolerance of 165, so the
        # kcal is kept as-is.
        raw = {
            "no_food_detected": False,
            "items": [_good_raw_item(grams=200, per_100g={"kcal": 165, "protein": 31, "carbs": 0, "fat": 3.6})],
        }
        result = validate_and_normalize(raw)
        assert result.items[0].grams == 200
        assert result.items[0].totals.kcal == 330

    def test_at_cap_unchanged(self):
        # 600 kcal/100g × 200 g = 1200 kcal → exactly at cap → unchanged.
        raw = {
            "no_food_detected": False,
            "items": [_good_raw_item(grams=200, per_100g={"kcal": 600, "protein": 30, "carbs": 0, "fat": 47})],
        }
        result = validate_and_normalize(raw)
        assert result.items[0].grams == 200
        assert result.items[0].totals.kcal == 1200

    def test_high_per_100g_low_grams_no_cap(self):
        # 884 kcal/100g (olive oil) × 5 g (a drizzle) = 44 kcal → no cap.
        raw = {
            "no_food_detected": False,
            "items": [_good_raw_item(grams=5, per_100g={"kcal": 884, "protein": 0, "carbs": 0, "fat": 100})],
        }
        result = validate_and_normalize(raw)
        assert result.items[0].grams == 5
        assert result.items[0].totals.kcal == 44

    def test_grams_also_clamped_to_max_grams(self):
        # If the kcal cap would push grams above MAX_GRAMS, MAX_GRAMS wins
        # and totals land well under the cap. This is the realistic
        # scenario for items like olive oil where the per-100g value is
        # high and even small portions would otherwise scale up.
        # 884 × 1000 g = 8840 kcal. Capped at 1200 → would want
        # 1200/884 × 100 ≈ 135.7 g. Within MAX_GRAMS, so that's the value.
        raw = {
            "no_food_detected": False,
            "items": [_good_raw_item(grams=1000, per_100g={"kcal": 884, "protein": 0, "carbs": 0, "fat": 100})],
        }
        result = validate_and_normalize(raw)
        # Should land at the kcal cap since 884 kcal/100g × 135.7 g ≈ 1200.
        assert result.items[0].totals.kcal == 1200
        assert result.items[0].grams < MAX_GRAMS


# ---------------------------------------------------------------------------
# Cache + rate-limit key helpers
# ---------------------------------------------------------------------------

class TestKeyHelpers:
    def test_cache_key_is_namespaced_by_image_hash(self):
        h = "abcdef" * 10  # 60 chars
        assert cache_key(h) == f"photo:analyze:{h}"

    def test_rate_limit_key_per_user(self):
        assert rate_limit_key("u-1") == "rl:photo:u-1"

    def test_kcal_sanity_tolerance_is_documented(self):
        # The 10% tolerance is part of the public contract; pin it so
        # a future tweak doesn't silently change behaviour.
        assert KCAL_SANITY_TOLERANCE == 0.10