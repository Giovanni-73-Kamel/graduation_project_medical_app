from __future__ import annotations

import argparse
import logging
import sys
from dataclasses import dataclass

import app.models as models
from app.config import settings
from app.database import SessionLocal
from app.services.reading_storage import prepare_reading_storage

logger = logging.getLogger(__name__)


@dataclass
class CompactStats:
    scanned: int = 0
    changed: int = 0
    skipped: int = 0
    ecg_samples_removed: int = 0
    ppg_samples_removed: int = 0


def _already_compacted(reading: models.RawReading) -> bool:
    metadata = reading.metadata_json or {}
    storage = metadata.get("storage") if isinstance(metadata, dict) else None
    return isinstance(storage, dict) and storage.get("policy") == "compact_invalid_channels_v1"


def compact_raw_readings(
    *,
    apply: bool = False,
    force: bool = False,
    batch_size: int = 500,
    limit: int | None = None,
) -> CompactStats:
    stats = CompactStats()
    db = SessionLocal()
    try:
        query = db.query(models.RawReading).order_by(models.RawReading.id.asc())
        remaining = None if limit is None else max(0, limit)

        offset = 0
        while True:
            if remaining == 0:
                break
            current_batch_size = max(1, batch_size)
            if remaining is not None:
                current_batch_size = min(current_batch_size, remaining)
            rows = query.offset(offset).limit(current_batch_size).all()
            if not rows:
                break
            for reading in rows:
                stats.scanned += 1
                if not force and _already_compacted(reading):
                    stats.skipped += 1
                    continue

                original_ecg_count = len(reading.ecg or [])
                original_ppg_count = len(reading.ppg or [])
                result = prepare_reading_storage(
                    ecg_values=reading.ecg or [],
                    ppg_values=reading.ppg or [],
                    status=reading.status,
                    metadata=reading.metadata_json or {},
                    compact_invalid_signals=settings.compact_invalid_reading_signals,
                    max_raw_signal_samples=settings.max_raw_signal_samples_per_reading,
                )
                changed = (
                    result.ecg != (reading.ecg or [])
                    or result.ppg != (reading.ppg or [])
                    or result.status != reading.status
                    or result.metadata != (reading.metadata_json or {})
                    or result.sample_count != reading.sample_count
                )
                if not changed:
                    stats.skipped += 1
                    continue

                stats.changed += 1
                stats.ecg_samples_removed += max(0, original_ecg_count - len(result.ecg))
                stats.ppg_samples_removed += max(0, original_ppg_count - len(result.ppg))

                if apply:
                    reading.ecg = result.ecg
                    reading.ppg = result.ppg
                    reading.status = result.status
                    reading.sample_count = result.sample_count
                    reading.metadata_json = result.metadata

            if apply:
                db.commit()
            else:
                db.rollback()

            if remaining is not None:
                remaining -= len(rows)

            if len(rows) < current_batch_size:
                break
            offset += len(rows)
    finally:
        db.close()
    return stats


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Compact old raw_readings rows using the same storage policy as live ingest."
    )
    parser.add_argument("--apply", action="store_true", help="Write changes to the database. Default is dry-run.")
    parser.add_argument("--force", action="store_true", help="Recompact rows that already have storage metadata.")
    parser.add_argument("--batch-size", type=int, default=500)
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    stats = compact_raw_readings(
        apply=args.apply,
        force=args.force,
        batch_size=args.batch_size,
        limit=args.limit,
    )
    mode = "APPLIED" if args.apply else "DRY-RUN"
    logger.info(
        "%s scanned=%s changed=%s skipped=%s ecg_samples_removed=%s ppg_samples_removed=%s",
        mode,
        stats.scanned,
        stats.changed,
        stats.skipped,
        stats.ecg_samples_removed,
        stats.ppg_samples_removed,
    )
    if not args.apply:
        logger.info("No rows were changed. Re-run with --apply to write these changes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
