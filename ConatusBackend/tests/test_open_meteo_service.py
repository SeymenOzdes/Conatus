import unittest

from services import open_meteo_service as service


class TideBuilderTests(unittest.TestCase):
    def test_rising_current_and_next_high(self):
        tide = service._build_tide(
            {"time": "2026-06-02T06:00", "sea_level_height_msl": 0.2},
            {
                "time": [
                    "2026-06-02T06:00",
                    "2026-06-02T07:00",
                    "2026-06-02T08:00",
                    "2026-06-02T09:00",
                ],
                "sea_level_height_msl": [0.2, 0.4, 0.6, 0.5],
            },
        )

        self.assertIsNotNone(tide)
        self.assertEqual(tide["current"]["state"], "rising")
        self.assertEqual(tide["current"]["next_extreme"]["type"], "high")
        self.assertEqual(tide["current"]["next_extreme"]["timestamp"], "2026-06-02T08:00")

    def test_falling_low_and_missing_data(self):
        tide = service._build_tide(
            {"time": "2026-06-02T06:00", "sea_level_height_msl": 0.7},
            {
                "time": [
                    "2026-06-02T06:00",
                    "2026-06-02T07:00",
                    "2026-06-02T08:00",
                    "2026-06-02T09:00",
                ],
                "sea_level_height_msl": [0.7, 0.4, 0.2, 0.3],
            },
        )

        self.assertIsNotNone(tide)
        self.assertEqual(tide["timeline"][0]["state"], "falling")
        self.assertEqual(tide["timeline"][2]["state"], "low")
        self.assertIsNone(service._build_tide({}, {"time": ["2026-06-02T06:00"]}))

    def test_high_and_steady_states(self):
        self.assertEqual(service._tide_state_at([0.1, 0.5, 0.2], 1), "high")
        self.assertEqual(service._tide_state_at([0.3, 0.31, 0.3], 1), "high")
        self.assertEqual(service._tide_state_at([0.3, 0.305], 0), "steady")


class ForecastSlotTests(unittest.TestCase):
    def test_three_hour_slot_scoring_and_daypart(self):
        hourly = [
            {
                "timestamp": f"2026-06-02T0{hour}:00",
                "wave_height_m": 1.5,
                "wave_period_s": 12,
                "swell_direction_deg": 270,
                "wind_speed_kmh": 8,
                "wind_direction_deg": 90,
                "precipitation_mm": 0,
                "weather_code": 0,
            }
            for hour in range(6, 9)
        ]
        tide = {
            "timeline": [
                {"timestamp": row["timestamp"], "sea_level_height_m": 0.2, "state": "rising"}
                for row in hourly
            ]
        }

        slots = service._build_forecast_slots(hourly, tide)

        self.assertEqual(len(slots), 1)
        self.assertEqual(slots[0]["part_of_day"], "morning")
        self.assertEqual(slots[0]["score"], 100)
        self.assertEqual(slots[0]["verdict"], "go")
        self.assertEqual(slots[0]["tide_state"], "rising")

    def test_slot_thresholds_and_best_windows(self):
        slots = [
            {
                "start_timestamp": "2026-06-02T06:00",
                "end_timestamp": "2026-06-02T09:00",
                "part_of_day": "morning",
                "wave_height_m": 0.4,
                "wave_period_s": 5,
                "wind_speed_kmh": 30,
                "tide_state": "falling",
                "score": 22,
                "verdict": "skip",
            },
            {
                "start_timestamp": "2026-06-02T09:00",
                "end_timestamp": "2026-06-02T12:00",
                "part_of_day": "morning",
                "wave_height_m": 1.0,
                "wave_period_s": 9,
                "wind_speed_kmh": 12,
                "tide_state": "rising",
                "score": 69,
                "verdict": "maybe",
            },
            {
                "start_timestamp": "2026-06-02T12:00",
                "end_timestamp": "2026-06-02T15:00",
                "part_of_day": "midday",
                "wave_height_m": 1.5,
                "wave_period_s": 12,
                "wind_speed_kmh": 8,
                "tide_state": "high",
                "score": 100,
                "verdict": "go",
            },
        ]

        windows = service._build_best_windows(slots)

        self.assertEqual(len(windows), 2)
        self.assertEqual(windows[0]["part_of_day"], "morning")
        self.assertEqual(windows[0]["score"], 69)
        self.assertIn("rising tide", windows[0]["summary"])
        self.assertEqual(windows[1]["part_of_day"], "midday")
        self.assertEqual(windows[1]["verdict"], "go")

    def test_score_thresholds(self):
        self.assertEqual(service._verdict(70), "go")
        self.assertEqual(service._verdict(40), "maybe")
        self.assertEqual(service._verdict(39), "skip")


if __name__ == "__main__":
    unittest.main()
