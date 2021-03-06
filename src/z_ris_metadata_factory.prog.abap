*&---------------------------------------------------------------------*
*& Report Z_RIS_METADATA_FACTORY
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT z_ris_metadata_factory.

DATA go_metadata TYPE REF TO cl_ris_shm_metadata.

go_metadata = cl_ris_metadata_factory=>get_instance( ).

ASSERT 1 = 1. " DEBUG HELPER
