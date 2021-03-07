*&---------------------------------------------------------------------*
*& Report Z_RIS_SHM_METADATA
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT z_ris_shm_metadata.

DATA: ls_data_models            TYPE ris_s_md_data_models,
      lt_data_models            TYPE ris_t_md_data_models,
      ls_model_implementation   TYPE ris_s_md_model_implementation,
      lt_model_implementation   TYPE ris_t_md_model_implementation,
      ls_ris_data_model         TYPE ris_data_model,
      lv_new                    TYPE boole_d,
      lt_ris_dm_types           TYPE TABLE OF ris_dm_types,
      ls_ris_dm_types           TYPE ris_dm_types,
      lo_type_descriptor        TYPE REF TO cl_abap_typedescr,
      lo_superclass_descriptor  TYPE REF TO cl_abap_classdescr,
      lo_class_descriptor       TYPE REF TO cl_abap_classdescr,
      lo_meta_model             TYPE REF TO cl_ris_meta_model,
      ls_metadata               TYPE ris_s_metadata,
      lv_default_implementation TYPE boole_d,
      ls_related_metadata       TYPE ris_s_metadata,
      ls_metadata_environment   TYPE ris_s_md_relationship,
      ls_metadata_where_used    TYPE ris_s_md_relationship.

FIELD-SYMBOLS: <ls_model_implementation> TYPE ris_s_md_model_implementation,
               <ls_related_metadata>     TYPE ris_s_metadata,
               <ls_existing_metadata>    TYPE ris_s_metadata.

" Deskriptor der Metamodell-Superklasse abholen
lo_superclass_descriptor ?= cl_abap_classdescr=>describe_by_name( 'CL_RIS_META_MODEL' ).

SELECT * FROM ris_data_model INTO ls_ris_data_model.
  " Gibt es den aktuellen Schlüssel schon in unserer internen Tabelle?
  CLEAR: ls_data_models, lv_new.
  READ TABLE lt_data_models INTO ls_data_models
                            WITH TABLE KEY trobjtype   = ls_ris_data_model-trobjtype
                                           subtype     = ls_ris_data_model-subtype
                                           legacy_type = ls_ris_data_model-legacy_type.
  IF sy-subrc <> 0.
    " Neu anlegen
    lv_new = abap_true.
    ls_data_models-trobjtype   = ls_ris_data_model-trobjtype.
    ls_data_models-subtype     = ls_ris_data_model-subtype.
    ls_data_models-legacy_type = ls_ris_data_model-legacy_type.
  ENDIF.

  CLEAR: ls_model_implementation.
  ls_model_implementation-type_name  = ls_ris_data_model-data_model_type.
  ls_model_implementation-class_name = ls_ris_data_model-meta_model_class.
  IF ls_model_implementation-type_name IS NOT INITIAL AND ls_model_implementation-class_name IS NOT INITIAL.
    INSERT ls_model_implementation INTO TABLE ls_data_models-model_implementations.
  ENDIF.

  IF lv_new = abap_true.
    INSERT ls_data_models INTO TABLE lt_data_models.
  ELSE.
    MODIFY TABLE lt_data_models FROM ls_data_models.
  ENDIF.

ENDSELECT.

" Einlesen der Modelltypenpriorität
SELECT * FROM ris_dm_types INTO TABLE lt_ris_dm_types ORDER BY priority. "#EC CI_BYPASS

** <ZZ>
*    DATA(zz_lt_legacy_metadata) = zz_get_legacy_metadata( ).
** </ZZ>

" Auslesen und abspeichern der Metadaten
LOOP AT lt_data_models INTO ls_data_models.

  "rd: this is a loop at the object types involved in RIS; example: ls_data_models-trobjtype = 'SVAL'

  lv_default_implementation = abap_true.
  " Welches Datenmodell können wir verwenden?
  " Suche nach Priorität (Sortierung bereits abgeschlossen)
  LOOP AT lt_ris_dm_types INTO ls_ris_dm_types.
    UNASSIGN: <ls_model_implementation>.
    READ TABLE ls_data_models-model_implementations ASSIGNING <ls_model_implementation> WITH TABLE KEY type_name = ls_ris_dm_types-type_name.
    IF sy-subrc = 0.
      " Überprüfen, ob angegebene Klasse existiert
      CLEAR: lo_type_descriptor, lo_class_descriptor.
      cl_abap_classdescr=>describe_by_name( EXPORTING  p_name         = <ls_model_implementation>-class_name
                                            RECEIVING  p_descr_ref    = lo_type_descriptor
                                            EXCEPTIONS type_not_found = 1
                                                       OTHERS         = 2 ).
      IF sy-subrc <> 0.
        " Klasse existiert nicht, weiter mit dem nächsten
        DELETE TABLE ls_data_models-model_implementations FROM <ls_model_implementation>.
        CONTINUE.
      ENDIF.
      TRY.
          lo_class_descriptor ?= lo_type_descriptor.
        CATCH cx_sy_move_cast_error.
          " Falls jemand Bosheiten in die Tabelle geschrieben hat
          DELETE TABLE ls_data_models-model_implementations FROM <ls_model_implementation>.
          CONTINUE.
      ENDTRY.

      DATA lv_superclass_exp_name TYPE string.
      lv_superclass_exp_name = lo_superclass_descriptor->get_relative_name( ).

      " Überprüfen, ob die Klasse auch wirklich ein Töchterchen unserer Superklasse ist
      IF  lv_superclass_exp_name NE lo_class_descriptor->get_super_class_type( )->get_relative_name( ).
        DATA lv_superclass_act_name TYPE string.
        lv_superclass_act_name = lo_class_descriptor->get_super_class_type( )->get_super_class_type( )->get_relative_name( ).
        IF lv_superclass_exp_name NE lv_superclass_act_name.
          DELETE TABLE ls_data_models-model_implementations FROM <ls_model_implementation>.
          CONTINUE.
        ENDIF.
      ENDIF.
      " Modellimplementierung gefunden
      IF lv_default_implementation EQ abap_true.
        <ls_model_implementation>-default_implementation = abap_true.
        CLEAR: lv_default_implementation.
      ENDIF.
      <ls_model_implementation>-priority = ls_ris_dm_types-priority.
    ENDIF.
  ENDLOOP.

  CLEAR ls_model_implementation.
  READ TABLE ls_data_models-model_implementations INTO ls_model_implementation WITH KEY default_implementation = abap_true.

  IF ls_model_implementation IS INITIAL.
    " Kein Modell gefunden --> Weitermachen mit dem nächsten Objekttypen
    CONTINUE.
  ENDIF.

  CLEAR: lo_meta_model, ls_metadata.
  ls_metadata-trobjtype   = ls_data_models-trobjtype.
  ls_metadata-subtype     = ls_data_models-subtype.
  ls_metadata-legacy_type = ls_data_models-legacy_type.
  TRY.
* <ZZ>
      IF ls_metadata-legacy_type IS INITIAL
          OR ls_model_implementation-class_name <> 'CL_RIS_META_MODEL_CLASSIC'  ##NO_TEXT.
* </ZZ>

      ELSE.

        CREATE OBJECT lo_meta_model TYPE (ls_model_implementation-class_name)
          EXPORTING
            iv_trobjtype   = ls_metadata-trobjtype
            iv_subtype     = ls_metadata-subtype
            iv_legacy_type = ls_metadata-legacy_type.
        lo_meta_model->get_metadata(
          IMPORTING
            et_search_groups   = ls_metadata-search_groups
            et_search_elements = ls_metadata-search_elements
            et_where_used      = ls_metadata-where_used
            et_environment     = ls_metadata-environment
            et_where_used_original_dynpro = ls_metadata-where_used_original_dynpro
            ).

        DATA lt_metadata TYPE ris_t_metadata.

        INSERT ls_metadata INTO TABLE lt_metadata.

      ENDIF.

    CATCH cx_root INTO DATA(lx).
      ASSERT 1 = 1.
  ENDTRY.

ENDLOOP.

ASSERT 1 = 1. " DEBUG HELPER
