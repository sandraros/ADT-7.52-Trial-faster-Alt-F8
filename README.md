# ADT Faster ALT+F8 with ABAP backend 7.40 SP 23

With ABAP Trial 7.40 SP 23, and ADT, if you use Alt+F8 to execute T.Code or anything else, when you enter a name, the search is very slow if the name is not already present in the history. The search takes something like 30 to 60 seconds.

The note [3006480 "Where-used list is not working"](https://launchpad.support.sap.com/#/notes/3006480) provides a solution for 7.53 and above, but not for 7.40 SP 23.

The general solution is to define the "metadata" as a constant in class `CL_RIS_SHM_METADATA` instead of executing lot of code at each search which in fact always generates the same metadata.

After that, it takes no more than 3 seconds.

How this solution was developed:
- I call once the program `Z_RIS_SHM_METADATA` to determine the metadata, and I used the adaptation of this [debugger tool](https://github.com/sandraros/abap_debugger_data_view_extension) to transform the generated metadata into ABAP code `DATA(...) = VALUE #( ... )`.
- I initialize this metadata in the new method `ZZ_GET_LEGACY_METADATA2` of class `CL_RIS_SHM_METADATA` via the Enhancement Framework
- I changed the methods `CONSTRUCTOR` and `INITIALIZE` via the Enhancement Framework to add code at the beginning of these 2 methods to call respectively the new methods `ZZ_CONSTRUCTOR` and `ZZ_INITIALIZE` (and leave the method after calling them, via `RETURN`) which are a copy of them + changed code as below (marked `<ZZ>...</ZZ>`):
  - Block 1:
    ```
        " Einlesen der Modelltypenpriorität
        SELECT * FROM ris_dm_types INTO TABLE lt_ris_dm_types ORDER BY priority. "#EC CI_BYPASS
    
    * <ZZ>
        DATA(zz_lt_legacy_metadata) = zz_get_legacy_metadata2( ).
    * </ZZ>
    
        " Auslesen und abspeichern der Metadaten
        LOOP AT lt_data_models INTO ls_data_models.
    ```
  - Block 2:
    ```
          TRY.
    * <ZZ>
              IF ls_metadata-legacy_type IS INITIAL
                  OR ls_model_implementation-class_name <> 'CL_RIS_META_MODEL_CLASSIC'  ##NO_TEXT.
    * </ZZ>
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
    * <ZZ>
              ELSE.
                READ TABLE zz_lt_legacy_metadata
                          WITH KEY  trobjtype   = ls_data_models-trobjtype
                                    subtype     = ls_data_models-subtype
                                    legacy_type = ls_data_models-legacy_type INTO ls_metadata.
              ENDIF.
    * </ZZ>
    
              ls_metadata-model_implementations = ls_data_models-model_implementations.
    ```
- 
- Now ALT+F8 will search faster.

NB: it's only tested for 7.40 SP 23. Use the same approach for other SP and other releases. For 7.53 and above, apply the note 3006480.

