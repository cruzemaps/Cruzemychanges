import os
import random
from typing import Dict, List, Optional, Tuple


def _get_here_hd_key() -> Optional[str]:
    return os.environ.get("HERE_HD_KEY")


def get_lane_geometry(route_coords: List[Tuple[float, float]], buffer_meters: int = 30) -> Dict:
    """
    Placeholder lane geometry fetcher.
    If HERE HD Live Map is configured, this should query lane geometry for the corridor.
    """
    here_key = _get_here_hd_key()
    if not here_key:
        return {
            "source": "mock",
            "buffer_meters": buffer_meters,
            "lanes": [
                {
                    "lane_id": "lane_center",
                    "polyline": route_coords,
                }
            ],
        }

    # TODO: Replace with HERE HD Live Map request once credentials are available.
    return {
        "source": "here_stub",
        "buffer_meters": buffer_meters,
        "lanes": [
            {
                "lane_id": "lane_center",
                "polyline": route_coords,
            }
        ],
    }


def match_lane(
    lat: float,
    lon: float,
    heading: Optional[float] = None,
    speed_mps: Optional[float] = None,
) -> Dict:
    """
    Placeholder lane matcher.
    Returns lane_id + confidence. If HERE HD Map is not configured, returns low confidence.
    """
    here_key = _get_here_hd_key()
    if not here_key:
        return {
            "lane_id": None,
            "confidence": 0.0,
            "source": "mock",
            "reason": "HERE_HD_KEY missing",
        }

    # TODO: Replace with HERE HD Live Map matching.
    # For now, return a deterministic mock lane based on heading.
    lane_id = "lane_through"
    if heading is not None:
        if 225 <= heading <= 315:
            lane_id = "lane_right"
        elif 45 <= heading <= 135:
            lane_id = "lane_left"

    confidence = 0.6 if speed_mps and speed_mps > 1 else 0.4
    # Add slight jitter to avoid a perfectly static mock.
    confidence = min(0.75, max(0.35, confidence + random.uniform(-0.05, 0.05)))

    return {
        "lane_id": lane_id,
        "confidence": round(confidence, 2),
        "source": "here_stub",
    }
