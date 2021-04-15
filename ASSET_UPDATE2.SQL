CREATE OR REPLACE package x_ycc_asset_update
PACKAGE BODY x_ycc_asset_update
as
AS
  --
  --
  g_sccsid      varchar2(100);
  -----------------------------------------------------------------------------
  g_body_sccsid varchar2(100);
  --
  --
  --   PVCS Identifiers :-
  --
  FUNCTION get_version
  RETURN varchar2;
  --       pvcsid           : $Header  :   x_ycc_asset_update.pkb $
  --
  --       Module Name      : $Workfile:   x_ycc_asset_update.pkb $
  --       Date into PVCS   : $Date    :   30 Apr 2019       $
  FUNCTION get_body_version
  RETURN varchar2;
  --       Date fetched Out : $Modtime :   30 Apr 2019       $
  --       PVCS Version     : $Revision:   1.0               $
  --
  Procedure show(msg in varchar2);
  --
  --
  --       Date Changed     : 30/04/2019
  --
  Procedure NullProc;
  -----------------------------------------------------------------------------
  --
  Procedure p$DataToDatabase( pi_debug in char default 'N');
  --  Copyright (c) exor corporation ltd, 2007
  --
  -----------------------------------------------------------------------------
end x_ycc_asset_update;
  -- **************************************************************************
  -- This package has been specifically written for York City
  -- **************************************************************************
  --
  -- The City of York have requested a piece of consultancy work which will allow
  -- them to take a file from a data collection device ( in csv format ) and to
  -- load the file into the Exor system.
  --
  -- The file will be used to:
  --   1. Update an existing asset.
  --   2. Create a new asset if one does not exist.
  --
  -- The file will contain SIGN data only.
  --
  -- The file will be loaded via a CSV data loader. A data definition will be
  -- created. An additional 6 attributes will also be created and these will be
  -- populated, initially with default values but where data is present in the
  -- provided data file the values will be loaded also.
  --
  -- This implementation of this procedure will be via the process framework.
  -- A log will be generated which will provide detailed information of the process
  -- execution.
  --
  -- ###################
  -- Constants
  -- ###################
  g_package_name CONSTANT VARCHAR2(30):= 'x_ycc_asset_update.pkb';
  --
  -- ###################
  -- Globals
  -- ###################
  --
  --
  -- ###################
  -- Exceptions
  -- ###################
  --
  --
  -- ##################
  -- Record Structures
  -- ##################
  --
  --
  -- ##################
  -- Variables
  -- ##################
  --
  dbug BOOLEAN:=false;
  --
  -----------------------------------------------------------------------------
  --
  -- ################################################
  -- ################ FUNCTIONS   ###################
  -- ################################################
  --
FUNCTION get_version
  RETURN VARCHAR2
IS
BEGIN
  RETURN g_sccsid;
END get_version;
--
-----------------------------------------------------------------------------
--
FUNCTION get_body_version
  RETURN VARCHAR2
IS
BEGIN
  RETURN g_body_sccsid;
END get_body_version;
--
-----------------------------------------------------------------------------
--
-- #################################################
-- ########## PROCEDURES ###########################
-- #################################################
--
PROCEDURE show
  (
    msg IN VARCHAR2)
        IS
BEGIN
  dbms_output.put_line(msg);
END;
--
-----------------------------------------------------------------------------
--
PROCEDURE NullProc
  /*  This procedure has been created for the CSV data loader
  we need an INSERT procedure that does nothing.
  */
IS
BEGIN
  NULL;
END NullProc;
--
-----------------------------------------------------------------------------
--
-- #################################################
-- ########## FILE FUNCTIONS #######################
-- #################################################
--
-----------------------------------------------------------------------------
--
PROCEDURE p$DataToDatabase
  (
    pi_debug IN CHAR DEFAULT 'N')
             IS
  SignRec       nm_inv_items_all%rowtype;
  vStg          VARCHAR2(100);
  vProcessId    hig_processes.hp_process_id%type DEFAULT hig_process_api.get_current_process_id;
  pi_batch      nm_ld_ycc_ast_upd_tmp.batch_no%type;
  AssetRec      nm_inv_items_all%rowtype;
  pi_ne_id      nm_elements_all.ne_id%type;
  pi_layer_id   nm_themes_all.nth_theme_id%type:=45;
  l_start_lref  NM_LREF;

  CURSOR c0
  IS
    SELECT batch_no,
      COUNT(*) occurance
    FROM nm_ld_ycc_ast_upd_tmp
    WHERE batch_no =( SELECT MAX(batch_no)
                      FROM   nm_ld_ycc_ast_upd_tmp
                    )
    and   nvl(iit_ne_id,0)>=0
    GROUP BY batch_no;

    CURSOR c1( pi_batch_no IN nm_ld_ycc_ast_upd_tmp.batch_no%type)
                         IS
    SELECT a.*
    FROM   nm_ld_ycc_ast_upd_tmp a
    ,      nm_load_batch_status  b
    WHERE  a.batch_no    = pi_batch_no
    and    a.batch_no    = b.nlbs_nlb_batch_no
    and    a.record_no   = b.nlbs_record_no
    and    b.nlbs_status = 'V' -- this will ensure that only VALID records are loaded.
    and    a.iit_ne_id>=0
    ORDER BY a.record_no;
  --
  c1Rec c1%rowtype;
  --
FUNCTION f$AssetExists(pi_ne_id IN nm_inv_items_all.iit_ne_id%type)
RETURN nm_inv_items%rowtype
IS
  CURSOR c1( pi_ne_id IN nm_inv_items_all.iit_ne_id%type)
  IS
    SELECT *
    FROM  nm_inv_items_all
    WHERE iit_ne_id= pi_ne_id;
  --
  c1Rec nm_inv_items_all%rowtype;
  --
BEGIN
  OPEN c1(pi_ne_id);
  FETCH c1 INTO c1rec;
  CLOSE c1;
  RETURN c1Rec;
END f$AssetExists;
FUNCTION f$SetBoolVal
  (
    piVal IN CHAR)
  RETURN BOOLEAN
            IS
  ok BOOLEAN:=false;
BEGIN
  IF upper(piVal)='Y' THEN
    ok          :=true;
  END IF;
  RETURN ok;
END f$SetBoolVal;
BEGIN
  dbug := f$SetBoolVal(pi_debug);
  dbms_output.enable(buffer_size => NULL);
  show('Starting ....');
  --nm3ctx.set_context('SNAP_ON',¿FALSE¿);
  --
  hig_process_api.log_it(pi_message => 'Info: Starting ....');
  -- Obtain the process id and put some output to the process.
  -- State the number of records to be processed.
  FOR i IN c0
  LOOP
    vStg:='Info: There are '||TO_CHAR(i.occurance)||' records to process in batch '||TO_CHAR(i.batch_no);
    hig_process_api.log_it(pi_message => vStg);
    pi_batch:=i.batch_no;
  END LOOP;
  /*
  Some of the following values can be ignored in the update.
  We may include them in the code for completeness but will probably ignore the values
  for the update. The admin unit for example should not change unless a boundary shift is
  performed OR if it was found that the initial admin unit was incorrect in the first place
  but if this is the case that it should be edited within the forms application ideally.
  */
  FOR i IN c1(pi_batch)
  LOOP
    SignRec.iit_ne_id            := i.iit_ne_id;
    SignRec.iit_primary_key      := i.iit_primary_key;
    SignRec.iit_start_date       := i.iit_start_date;
    SignRec.iit_date_created     := i.iit_date_created;
    SignRec.iit_date_modified    := i.iit_date_modified;
    SignRec.iit_created_by       := i.iit_created_by;
    if nvl(i.iit_admin_unit,0)=0
    then SignRec.iit_admin_unit:=1;
    else SignRec.iit_admin_unit:=i.iit_admin_unit;
    end if;
    SignRec.iit_note             := i.iit_note;
    SignRec.iit_peo_invent_by_id := i.iit_peo_invent_by_id;
    SignRec.iit_x_sect           := i.iit_x_sect;
    SignRec.iit_id_code          := i.iit_id_code;
    SignRec.iit_type             := i.iit_type;
    SignRec.iit_class            := i.iit_class;
    SignRec.iit_type_txt         := i.iit_type_txt;
    SignRec.iit_method           := i.iit_method;
    SignRec.iit_width            := i.iit_width;
    SignRec.iit_height           := i.iit_height;
    SignRec.iit_material         := i.iit_material;
    SignRec.iit_x                := i.easting;
    SignRec.iit_y                := i.northing;
    SignRec.iit_inv_type         := NVL(i.iit_inv_type,'SG');
    SignRec.iit_num_attrib96     := i.metalposts;       -- 1. Additional
    SignRec.iit_num_attrib97     := i.circcrosssection; -- 2. Additional
    SignRec.iit_chr_attrib26     := i.signfacia;        -- 3. Additional
    SignRec.iit_date_attrib86    := i.structtestdate;   -- 4. Additional
    SignRec.iit_chr_attrib27     := i.outcome;          -- 5. Additional
    SignRec.iit_date_attrib87    := i.retestdate;       -- 6. Additional
    --
    IF dbug THEN
      hig_process_api.log_it(pi_message =>'Info: IIT_NE_ID  : '||TO_CHAR(SignRec.iit_ne_id));
      hig_process_api.log_it(pi_message =>'Info: PK         : '||TO_CHAR(SignRec.iit_primary_key));
      hig_process_api.log_it(pi_message =>'Info: XSP        : '||SignRec.iit_x_sect);
      hig_process_api.log_it(pi_message =>'Info: Asset Type : '||SignRec.iit_inv_type);
      hig_process_api.log_it(pi_message =>'Info: Admin Unit : '||to_char(SignRec.iit_admin_unit));
      hig_process_api.log_it(pi_message =>'Info: Descr      : '||SignRec.iit_descr);
      hig_process_api.log_it(pi_message =>'Info: Note       : '||SignRec.iit_note);
      hig_process_api.log_it(pi_message =>'Info: Invent By  : '||TO_CHAR(SignRec.iit_peo_invent_by_id));
      hig_process_api.log_it(pi_message =>'Info: End Date   : '||TO_CHAR(SignRec.iit_end_date,'DD-MON-YYYY'));
      hig_process_api.log_it(pi_message =>'Info: Id Code    : '||SignRec.iit_id_code);
      hig_process_api.log_it(pi_message =>'Info: Class      : '||SignRec.iit_class);
      hig_process_api.log_it(pi_message =>'Info: Type Text  : '||SignRec.iit_type_txt);
      hig_process_api.log_it(pi_message =>'Info: Method     : '||SignRec.iit_method);
      hig_process_api.log_it(pi_message =>'Info: Width      : '||TO_CHAR(SignRec.iit_width));
      hig_process_api.log_it(pi_message =>'Info: Height     : '||TO_CHAR(SignRec.iit_height));
      hig_process_api.log_it(pi_message =>'Info: Material   : '||SignRec.iit_material);
      hig_process_api.log_it(pi_message =>'Info: Easting    : '||TO_CHAR(SignRec.iit_x));
      hig_process_api.log_it(pi_message =>'Info: Northing   : '||TO_CHAR(SignRec.iit_y));
      hig_process_api.log_it(pi_message =>'Info: Metalposts : '||TO_CHAR(SignRec.iit_num_attrib96));
      hig_process_api.log_it(pi_message =>'Info: Circ Cross : '||TO_CHAR(SignRec.iit_num_attrib97));
      hig_process_api.log_it(pi_message =>'Info: Facia      : '||SignRec.iit_chr_attrib26);
      hig_process_api.log_it(pi_message =>'Info: Test Date  : '||TO_CHAR(SignRec.iit_date_attrib86,'DD-MON-YYYY'));
      hig_process_api.log_it(pi_message =>'Info: Outcome    : '||SignRec.iit_chr_attrib27);
      hig_process_api.log_it(pi_message =>'Info: RetestDate : '||TO_CHAR(SignRec.iit_date_attrib87,'DD-MON-YYYY'));
    END IF;
    --
    hig_process_api.log_it(pi_message =>'Info: Validating record ('||TO_CHAR(i.record_no)||') now.');
    nm3inv.validate_rec_iit(SignRec);
    hig_process_api.log_it(pi_message =>'Info: Record validated.');
    --
    AssetRec:=f$AssetExists(i.iit_ne_id);
    --
    IF dbug THEN
      IF NVL(AssetRec.iit_ne_id,0)>0 THEN
        show('Info: Sign asset located and ready for update.');
      ELSE
        show('Info: Sign asset not located. Unable to update.');
      END IF;
    END IF;
    --
    IF nvl(AssetRec.iit_ne_id,0)>0
    THEN -- Here we only really ideally want to update values that have changed.
         -- but for the moment we will have to function on the overall functionlity.
      hig_process_api.log_it(pi_message =>'Info: Updating record '||TO_CHAR(i.record_no));
      --

      nm3api_inv_sg.upd_attr(p_iit_ne_id      => SignRec.iit_ne_id
                            ,p_effective_date => To_Date(Sys_Context('NM3CORE','EFFECTIVE_DATE'),'DD-MON-YYYY')
                            ,pf_iit_id_code   => SignRec.iit_id_code
                            ,pf_iit_type      => SignRec.iit_type
                            ,pf_iit_class     => SignRec.iit_class
                            ,pf_iit_type_txt  => SignRec.iit_type_txt
                            ,pf_iit_method    => SignRec.iit_method
                            ,pf_iit_width     => SignRec.iit_width
                            ,pf_iit_height    => SignRec.iit_height
                            ,pf_iit_material  => SignRec.iit_material
                            ,pf_easting       => SignRec.iit_x
                            ,pf_northing      =>  SignRec.iit_y
                            ,pf_iit_metal_posts =>SignRec.iit_num_attrib96        -- 1. Additional
                            ,pf_iit_circ_crossection =>SignRec.iit_num_attrib97   -- 2. Additional
                            ,pf_iit_sign_facia       =>SignRec.iit_chr_attrib26   -- 3. Additional
                            ,pf_iit_struct_test_date =>SignRec.iit_date_attrib86  -- 4. Additional
                            ,pf_iit_outcome           =>SignRec.iit_chr_attrib27   -- 5. Additional
                            ,pf_iit_retest_date      =>SignRec.iit_date_attrib87);  -- 6. Additional
      /*
      update nm_inv_items_all
      set iit_date_modified   = SignRec.iit_date_modified
      ,  iit_created_by       = SignRec.iit_created_by
      ,  iit_descr            = SignRec.iit_descr
      ,  iit_note             = SignRec.iit_note
      ,  iit_peo_invent_by_id = SignRec.iit_peo_invent_by_id
      ,  iit_x_sect           = SignRec.iit_x_sect
      ,  iit_end_date         = SignRec.iit_end_date
      ,  iit_id_code          = SignRec.iit_id_code
      ,  iit_type             = SignRec.iit_type
      ,  iit_class            = SignRec.iit_class
      ,  iit_type_txt         = SignRec.iit_type_txt
      ,  iit_method           = SignRec.iit_method
      ,  iit_width            = SignRec.iit_width
      ,  iit_height           = SignRec.iit_height
      ,  iit_material         = SignRec.iit_material
      ,  iit_x                = SignRec.iit_x
      ,  iit_y                = SignRec.iit_y
      ,  iit_num_attrib96     = SignRec.iit_num_attrib96         -- 1. Additional
      ,  iit_num_attrib97     = SignRec.iit_num_attrib97         -- 2. Additional
      ,  iit_chr_attrib26     = SignRec.iit_chr_attrib26         -- 3. Additional
      ,  iit_date_attrib86    = SignRec.iit_date_attrib86        -- 4. Additional
      ,  iit_chr_attrib27     = SignRec.iit_chr_attrib27         -- 5. Additional
      ,  iit_date_attrib87    = SignRec.iit_date_attrib87        -- 6. Additional
      where iit_ne_id = SignRec.iit_ne_id;
      */
      --
      hig_process_api.log_it(pi_message =>'Info: Asset attributes updated.');
      --
    ELSE -- Create and locate a new asset
      hig_process_api.log_it(pi_message =>'Info: Creating new SIGN asset for record '||TO_CHAR(i.record_no));
      --
      /*
      nm3api_inv_sg.ins(p_iit_ne_id     =>SignRec.iit_ne_id
                       ,p_effective_date=>To_Date(Sys_Context('NM3CORE','EFFECTIVE_DATE'),'DD-MON-YYYY')
                       ,p_admin_unit    =>SignRec.iit_admin_unit
                       ,p_x_sect        =>SignRec.iit_x_sect
                       ,p_descr         =>SignRec.iit_descr
                       ,p_note          =>SignRec.iit_note
                       ,pf_iit_id_code  =>SignRec.iit_id_code
                       ,pf_iit_type     =>SignRec.iit_type
                       ,pf_iit_class    =>SignRec.iit_class
                       ,pf_iit_type_txt =>SignRec.iit_type_txt
                       ,pf_iit_method   =>SignRec.iit_method
                       ,pf_iit_width    =>SignRec.iit_width
                       ,pf_iit_height   =>SignRec.iit_height
                       ,pf_iit_material =>SignRec.iit_material
                       ,pf_easting      =>SignRec.iit_x
                       ,pf_northing     =>SignRec.iit_y
                       ,pf_iit_metal_posts      =>SignRec.iit_num_attrib96  -- 1. Additional
                       ,pf_iit_circ_crossection =>SignRec.iit_num_attrib97  -- 2. Additional
                       ,pf_iit_sign_facia       =>SignRec.iit_chr_attrib26  -- 3. Additional
                       ,pf_iit_struct_test_date =>SignRec.iit_date_attrib86 -- 4. Additional
                       ,pf_iit_outcome          =>SignRec.iit_chr_attrib27   -- 5. Additional
                       ,pf_iit_retest_date      =>SignRec.iit_date_attrib87);      -- 6. Additional);
      */
      nm3api_inv.create_inventory_item(p_rec_iit        => SignRec
                                     , p_effective_date => trunc(sysdate)
                                      );
      --
      hig_process_api.log_it(pi_message =>'Info: Sign asset created.');
      --
      COMMIT;
      --
    END IF;
  END LOOP;
END p$DataToDatabase;
END x_ycc_asset_update;
SQL> SPOOL OFF
