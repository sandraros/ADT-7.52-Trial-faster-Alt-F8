# ADT-7.52-Trial-faster-Alt-F8
With ABAP Trial 7.52 SP 0 or 1, and ADT, if you use Alt+F8 to execute T.Code or anything else, when you enter a name, the search is very slow if the name is not already present in the history. The search takes something like 30 to 60 seconds.

The note [3006480 "Where-used list is not working"](https://launchpad.support.sap.com/#/notes/3006480) provides a solution for 7.53 and above, but not for 7.52.

The general solution is to define the "metadata" as a constant in class `CL_RIS_SHM_METADATA` instead of executing lot of code at each search which in fact always generates the same metadata.

After that, it takes no more than 3 seconds.

How this solution was developed:
- I install first the [DVE debugger tool](https://github.com/objective-partner/abap_debugger_data_view_extension) 
- I install this program [`Z_RIS_SHM_METADATA`](https://github.com/sandraros/ADT-7.52-Trial-faster-Alt-F8/blob/7.52-SP-0/src/z_ris_shm_metadata.prog.abap)
- I add a breakpoint at the end of `Z_RIS_SHM_METADATA`, run the program, run the DVE tool to display the variable `lt_metadata` as ABAP code `VALUE #( ... )` (takes 3 minutes to display it, there are tens of thousands of lines).
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

NB: it's only tested for 7.52 SP 0 and 1. Use the same approach for 7.52 SP 4 for instance. For 7.53 and above, apply the note 3006480.
