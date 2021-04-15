--------------------------------------------------------
--  DDL for Package X_YCC_ASSET_UPDATE
--------------------------------------------------------

  CREATE OR REPLACE PACKAGE "HIGHWAYS"."X_YCC_ASSET_UPDATE" 
as
  --
  g_sccsid      varchar2(100);
  g_body_sccsid varchar2(100);
  --
  FUNCTION get_version
  RETURN varchar2;
  --
  FUNCTION get_body_version
  RETURN varchar2;
  --
  Procedure show(msg in varchar2);
  --
  Procedure NullProc;
  --
  Procedure p$DataToDatabase( pi_debug in char default 'N');
  --
end x_ycc_asset_update;

/
