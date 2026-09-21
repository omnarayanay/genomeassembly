from pydantic import BaseModel, Field
from typing import Optional, List
from enum import Enum
import uuid

class ReadType(str, Enum):
    short = "short"
    long = "long"
    hybrid = "hybrid"

class OrganismType(str, Enum):
    bacterial = "bacterial"
    eukaryotic = "eukaryotic"

class SampleInfo(BaseModel):
    sample_id: str
    read_type: str  # "short", "long", "hybrid"
    read1: Optional[str] = None
    read2: Optional[str] = None
    long_reads: Optional[str] = None
    assembly_fasta: Optional[str] = None
    expected_genome_size: str
    organism_type: str

class PipelineParams(BaseModel):
    starting_point: Optional[str] = "reads"
    busco_lineage: Optional[str] = "bacteria_odb10"
    taxid: Optional[str] = "4910"
    selected_tools: Optional[List[str]] = Field(default_factory=list)

class SampleSheet(BaseModel):
    samples: List[SampleInfo]
    params: Optional[PipelineParams] = None

class RunStatus(str, Enum):
    queued = "queued"
    running = "running"
    done = "done"
    failed = "failed"
    cancelled = "cancelled"

class RunRecordResponse(BaseModel):
    run_id: str
    status: RunStatus
    current_stage: Optional[str] = None
    created_at: str
    started_at: Optional[str] = None
    finished_at: Optional[str] = None
    log_path: Optional[str] = None
