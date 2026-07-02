"""hardware backend clinical integration features

Revision ID: d1e2f3a4b5c6
Revises: b7c4e2a91d10
Create Date: 2026-06-28

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d1e2f3a4b5c6"
down_revision: Union[str, Sequence[str], None] = "b7c4e2a91d10"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("devices", sa.Column("patient_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_devices_patient_id_users",
        "devices",
        "users",
        ["patient_id"],
        ["id"],
        ondelete="SET NULL",
    )

    op.create_table(
        "medical_records",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("patient_id", sa.Integer(), nullable=False),
        sa.Column("doctor_id", sa.Integer(), nullable=True),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("diagnosis", sa.String(), nullable=True),
        sa.Column("notes", sa.String(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), server_default=sa.text("'{}'"), nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["doctor_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["patient_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "prescriptions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("appointment_id", sa.Integer(), nullable=True),
        sa.Column("patient_id", sa.Integer(), nullable=False),
        sa.Column("doctor_id", sa.Integer(), nullable=True),
        sa.Column("medication_name", sa.String(), nullable=False),
        sa.Column("dosage", sa.String(), nullable=True),
        sa.Column("frequency", sa.String(), nullable=True),
        sa.Column("instructions", sa.String(), nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["appointment_id"], ["appointments.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["doctor_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["patient_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "lab_results",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("appointment_id", sa.Integer(), nullable=True),
        sa.Column("patient_id", sa.Integer(), nullable=False),
        sa.Column("doctor_id", sa.Integer(), nullable=True),
        sa.Column("test_name", sa.String(), nullable=False),
        sa.Column("result_value", sa.String(), nullable=True),
        sa.Column("unit", sa.String(), nullable=True),
        sa.Column("reference_range", sa.String(), nullable=True),
        sa.Column("notes", sa.String(), nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["appointment_id"], ["appointments.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["doctor_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["patient_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "clinics",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("address", sa.String(), nullable=True),
        sa.Column("phone", sa.String(), nullable=True),
        sa.Column("specialty", sa.String(), nullable=True),
        sa.Column("metadata_json", sa.JSON(), server_default=sa.text("'{}'"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "medications",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("category", sa.String(), nullable=True),
        sa.Column("dosage_form", sa.String(), nullable=True),
        sa.Column("description", sa.String(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_medications_name", "medications", ["name"], unique=False)
    op.create_table(
        "clinical_alerts",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("patient_id", sa.Integer(), nullable=True),
        sa.Column("session_id", sa.String(), nullable=False),
        sa.Column("analysis_id", sa.Integer(), nullable=True),
        sa.Column("severity", sa.String(), server_default="medium", nullable=False),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column("message", sa.String(), nullable=False),
        sa.Column("status", sa.String(), server_default="open", nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["analysis_id"], ["analysis_results.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["patient_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["session_id"], ["sessions.session_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade() -> None:
    op.drop_table("clinical_alerts")
    op.drop_index("ix_medications_name", table_name="medications")
    op.drop_table("medications")
    op.drop_table("clinics")
    op.drop_table("lab_results")
    op.drop_table("prescriptions")
    op.drop_table("medical_records")
    op.drop_constraint("fk_devices_patient_id_users", "devices", type_="foreignkey")
    op.drop_column("devices", "patient_id")
