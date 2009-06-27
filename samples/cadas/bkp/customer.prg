#include "FiveWin.ch"
#include "Customer.ch"

#include "SQLLIB.ch"

REQUEST SQLLIB
REQUEST PGSQL
REQUEST DBFCDX
REQUEST HB_LANG_PT

/*
---------------------------------------------------------------------------------------------------------------

1o Problema:

* Tratar nome de tabelas maiusculas / minusculas

Ex: digamos que eu tenha o seguinte banco de dados "demosqllib" e eu fa�a o seguinte teste:
    if SL_DATABASE( "Demosqllib" )
    endif
    Veja que digitei "Demosqllib" com "D" maiusculo, neste caso nao est� achando a tabela.

---------------------------------------------------------------------------------------------------------------

2o Problema:

* A fun��o SL_DATABASE() quando n�o est� trabalhando corretamente quando o BD n�o est� conectado.

Veja o exemplo abaixo:

function main
 
   if !SL_DATABASE( "demosqllib" ) <<- Veja que aqui que eu ainda n�o estabeleci uma conex�o com o postgres
      SQL CREATE DATABASE "demosqllib" INTO lRet
   endif

   SQL CONNECT ON cHost ;
             USER cUser ;
         PASSWORD cPass ;
         DATABASE "demosqllib" ;  <<--- ... E para me coenctar ao BD eu preciso que a tabela j� exista.
              LIB "PGSQL" ;                 
           SCHEMA "public" ;
             INTO nConn  

eturn NIL

   Pergunta: Teria como eu me conectar ao postgres sem ter a necessidade de me conectar a um BD ? Porque a� 
             acho que a fun��o SL_DATABASE funcionaria corretamente. Tipo assim:

function main
 
   SQL CONNECT ON cHost ;  && Veja que aqui n�o especifiquei o "DATABASE"
             USER cUser ;
         PASSWORD cPass ;
              LIB "PGSQL" ;                 
           SCHEMA "public" ;
             INTO nConn  

   if !SL_DATABASE( "demosqllib" ) <<- Acho que assim retornaria .T.
      SQL CREATE DATABASE "demosqllib" INTO lRet
   endif

return NIL

.. Ou existiria uma forma melhor de se fazer isto ?

---------------------------------------------------------------------------------------------------------------

3o Problema:

dbappend() - nao esta incluindo o registro na tabela

---------------------------------------------------------------------------------------------------------------

4o Problema:

dbdelete() - nao esta excluindo o registro da tabela

---------------------------------------------------------------------------------------------------------------

5o Problema:

o xBrowse do Fivewin n�o est� funcionando.

---------------------------------------------------------------------------------------------------------------

6o Problema:
   
   Ao editar uma tabela e gravar "Record", e ao sair da tela d� o erro abaixo:
    
   Error occurred at: 10/06/2009, 16:17:43
   Error description: Error BASE/1132  Erro de limite: acesso de array
   Args:
     [   1] = A   
     [   2] = N   13

Stack Calls
===========
   Called from: sl_wabase.prg => SL_GETVALUE_WA(769)
   Called from: sl_wabase.prg => SL_BUILDWHERESTR(2965)

---------------------------------------------------------------------------------------------------------------

7o Problema:

   N�o est� respeitando a variavel "FWVERSION", sempre usa a "msgstop" da sqllib e n�o do fivewin.

---------------------------------------------------------------------------------------------------------------
*/

static oWnd, oClients, oClient, oName, oAddress, oState, oSalary
static cName, oBrw, cAddress, cState, nSalary
static oBtnUp, oBtnDn, oBtnEd, oBtnCa, oBtnRe, oBtnNe, oBtnDe

//----------------------------------------------------------------------------//

function Main()

   local oBar, aFiles, lRet, nServer, nDb

   HB_LANGSELECT( "PT" )

   set date     to BRITISH
   set deleted  ON
   set century  ON

   SET AUTOPEN  OFF
   SET AUTORDER TO 1

   SET _3DLOOK  ON

   cHost := "localhost"
   cUser := "postgres"
   cPass := "postgres"

   SQL CONN PARAMS TO HOST cHost ;
                      USER cUser ;
                  PASSWORD cPass ;
                       VIA "PGSQL"

msgstop( "existe demosqllib ?:" + cvaltochar(SL_DATABASE( "demosqllib" )) )  && aqui sempre est� retornando .F.
/*
   SQL CONNECT SERVER ON cHost   ;
                    USER cUser   ;
                PASSWORD cPass   ;
                    INTO nServer
*/

nServer1 := PQsetdbLogin( cHost, "5432", "", "", "template1", cUser, cPass )
msgstop( hb_valtostr( PQDB( nServer1 ) ) )

nServer2 := PQsetdbLogin( cHost, "5432", "", "", "demosqllib", cUser, cPass )
msgstop( hb_valtostr( PQDB( nServer2 ) ) )

msgstop( "nserver1: " + hb_valtostr(nServer1) + CRLF + ;
         "nserver2: " + hb_valtostr(nServer2) )

msgstop( "existe demosqllib ?:" + cvaltochar(SL_DATABASE( "demosqllib" )) )  && aqui sempre est� retornando .F.

   if !SL_DATABASE( "demosqllib" )
      SQL CREATE DATABASE "demosqllib" INTO lRet
msgstop( "lRet: " + cvaltochar(lRet) )
   endif

   SQL CONNECT DATABASE "demosqllib" ;
                 SERVER nServer      ;
                 SCHEMA "public"     ;
                   INTO nDb

msgstop( "nDb: " + hb_valtostr(nDb) )

   if !SL_FILE( "customer" )
      aFiles := { "Customer.dbf", "sales.dbf" }
      SQL IMPORT DBF aFiles VIA "DBFCDX" PACK INTO lRet
   else
      lRet := .T.
   endif

   USE Customer ALIAS "customer" via "SQLLIB" exclusive

   USE sales alias "sales" via "SQLLIB" NEW exclusive

   SELECT customer

   DEFINE WINDOW oWnd TITLE "Reporting tools" MDI ;
      MENU BuildMenu() COLOR "N/W"

   DEFINE BUTTONBAR oBar OF oWnd SIZE 60, 60 2007

   DEFINE BUTTON OF oBar ACTION MsgInfo( "Click" ) ;
      FILENAME "\fwh\bitmaps\attach.bmp" PROMPT "Attach"

   DEFINE BUTTON OF oBar ACTION MsgInfo( "Click" ) ;
      FILENAME "\fwh\bitmaps\calendar.bmp" PROMPT "Calendar"

   DEFINE BUTTON OF oBar ACTION MsgInfo( "Click" ) ;
      FILENAME "\fwh\bitmaps\people2.bmp" PROMPT "Clients"

   DEFINE BUTTON OF oBar ACTION MsgInfo( "Click" )

   SET MESSAGE OF oWnd TO "Testing the FiveWin Report Class" CENTERED

   ACTIVATE WINDOW oWnd ;
      VALID MsgYesNo( "Do you want to end?" )

   dbcloseall()

   SQL DISCONNECT FROM nServer

return nil

//----------------------------------------------------------------------------//

function BuildMenu()

   local oMenu

   MENU oMenu
      MENUITEM "&DataBases"
      MENU
         MENUITEM "&Clients..." ACTION  BrwClients() ;
            MESSAGE "Clients management"

         MENUITEM "&End" ACTION oWnd:End() ;
            MESSAGE "End this test"

      ENDMENU

      oMenu:AddMdi()              // Add standard MDI menu options

   ENDMENU

return oMenu

//----------------------------------------------------------------------------//

function BrwClients()

   local oIco, oBar

   if oClients != nil
      return nil
   endif

   DEFINE ICON oIco FILENAME "\fwh\icons\customer.ico"

   DEFINE WINDOW oClients TITLE "Clients management" ;
      MDICHILD ICON oIco

   DEFINE BUTTONBAR oBar OF oClients

   DEFINE BUTTON OF oBar ACTION ShowClient()
/*
   @ 3, 0 XBROWSE oBrw OF oClients ALIAS "customer" AUTOCOLS && FASTEDIT LINES CELL
      
   oBrw:bKeyChar = { | nKey | If( nKey == VK_ESCAPE, oClients:End(), NIL ) }   

   oBrw:CreateFromCode()
   oClients:oClient := oBrw
*/
   @ 2, 0 LISTBOX oBrw FIELDS OF oClients ;
      SIZE 500, 500 ;
      ON CHANGE ChangeClient()

   oClients:SetControl( oBrw )

   ACTIVATE WINDOW oClients ;
      VALID( oClients := nil, .t. )        // We destroy the object

return nil

//----------------------------------------------------------------------------//

function ShowClient()

   local oIco

   nSalary := 0

   if oClient != nil
      return nil
   endif

   DEFINE ICON oIco FILENAME "\fwh\icons\Person.ico"

   DEFINE DIALOG oClient RESOURCE "CLIENT" ;
      ICON oIco

   REDEFINE SAY ID 3 OF oClient
   REDEFINE SAY ID 4 OF oClient
   REDEFINE SAY ID 5 OF oClient
   REDEFINE SAY ID 6 OF oClient

   REDEFINE GET oName    VAR cName    ID ID_NAME    OF oClient
   REDEFINE GET oAddress VAR cAddress ID ID_ADDRESS OF oClient
   REDEFINE GET oState   VAR cState   ID ID_STATE   OF oClient
   REDEFINE GET oSalary  VAR nSalary  ID ID_SALARY  PICT "@E 999999.99" OF oClient
   
   REDEFINE BUTTON oBtnUp ID ID_PREV OF oClient ACTION GoReg( "UP" )

   REDEFINE BUTTON oBtnDn ID ID_NEXT OF oClient ACTION GoReg( "DOWN" )

   REDEFINE BUTTON oBtnEd ID ID_EDIT OF oClient ACTION EDIT()

   REDEFINE BUTTON oBtnCa ID ID_CANC OF oClient ACTION CANCEL()

   REDEFINE BUTTON oBtnRe ID ID_RECO OF oClient ACTION RECORD()

   REDEFINE BUTTON oBtnNe ID ID_NEW  OF oClient ACTION NEWREG()

   REDEFINE BUTTON oBtnDe ID ID_DEL  OF oClient ACTION DELREG()

   SELECT Sales     // We select Sales to properly initialize the Browse

   REDEFINE LISTBOX FIELDS ID ID_SALES OF oClient

   CANCEL()
   
   ACTIVATE DIALOG oClient CENTERED NOWAIT ;
      VALID ( oClient := nil, .t. )           // Destroy the object

   SELECT customer
   
   ChangeClient()
   
return nil

//----------------------------------------------------------------------------//

function NEWREG

customer->( dbappend() )
customer->( dbcommit() )

oBrw:GoBottom()

oBrw:refresh()

return nil

//----------------------------------------------------------------------------//

function DELREG

   msgrun( "", , { || .T. } )

customer->( dbdelete() )
customer->( dbcommit() )

oBrw:refresh()

return nil

//----------------------------------------------------------------------------//

function EDIT

   oName:enable()
   oAddress:enable()
   oState:enable()
   oSalary:enable()

   oBtnUp:disable()
   oBtnDn:disable()
   oBtnEd:disable()
   oBtnNe:disable()
   oBtnDe:disable()
   oBtnRe:enable()
   oBtnCa:enable()

   oName:setfocus()

return nil

//----------------------------------------------------------------------------//

function CANCEL

   oName:disable()
   oAddress:disable()
   oState:disable()
   oSalary:disable()
   oBtnUp:enable()
   oBtnDn:enable()
   oBtnEd:enable()
   oBtnCa:disable()
   oBtnRe:disable()
   oBtnNe:enable()
   oBtnDe:enable()
   
return nil

//----------------------------------------------------------------------------//

function RECORD

      customer->First  := cName
      customer->Street := cAddress
      customer->State  := cState
      customer->salary := nSalary
          
      oBrw:DrawSelect()
      
      CANCEL()
   
return nil

//----------------------------------------------------------------------------//

function ChangeClient()

   if oClient != nil
      cName := customer->First
      oName:Refresh()
      cAddress := customer->Street
      oAddress:Refresh()
      cState := customer->State
      oState:Refresh()
      oSalary:varput( customer->salary )
      oSalary:Refresh()
   endif

return nil

//----------------------------------------------------------------------------//

function GoReg( cTipo )

   msgrun( "", , { || .T. } )

   if oClients != nil
      if cTipo == "UP"
         oClients:oControl:GoUp()
      else
         oClients:oControl:GoDown()
      endif
   else
      if cTipo == "UP"
         SKIP -1
         if boF()
            GO TOP
         endif
      else
         SKIP 1
         if EoF()
            GO BOTTOM
         endif
      endif
   endif

   ChangeClient()

return nil

//----------------------------------------------------------------------------//
