/*
 * $Id: mssgline.prg 7155 2007-04-14 10:41:54Z vszakats $
 */

/*
 * Harbour Project source code:
 * TMENUSYS class
 *
 * Copyright 2002 Larry Sevilla <lsevilla@nddc.edu.ph>
 * www - http://www.harbour-project.org
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this software; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place, Suite 330,
 * Boston, MA 02111-1307 USA (or visit the web site http://www.gnu.org/).
 *
 * As a special exception, the Harbour Project gives permission for
 * additional uses of the text contained in its release of Harbour.
 *
 * The exception is that, if you link the Harbour libraries with other
 * files to produce an executable, this does not by itself cause the
 * resulting executable to be covered by the GNU General Public License.
 * Your use of that executable is in no way restricted on account of
 * linking the Harbour library code into it.
 *
 * This exception does not however invalidate any other reasons why
 * the executable file might be covered by the GNU General Public License.
 *
 * This exception applies only to the code released by the Harbour
 * Project under the name Harbour.  If you copy code from other
 * Harbour Project or Free Software Foundation releases into a copy of
 * Harbour, as the General Public License permits, the exception does
 * not apply to the code that you add in this way.  To avoid misleading
 * anyone as to the status of such modified files, you must delete
 * this exception notice from them.
 *
 * If you write modifications of your own for Harbour, it is your choice
 * whether to permit this exception to apply to your modifications.
 * If you do not wish that, delete this exception notice.
 *
 */

#include "hbclass.ch"

#include "common.ch"
#include "getexit.ch"
#include "inkey.ch"
#include "setcurs.ch"

/* NOTE: Harbour doesn't support CA-Cl*pper 5.3 GUI functionality, but
         it has all related variables and methods. */

#ifdef HB_COMPAT_C53

/* Class to simulate menusys.prg of CA-Cl*pper 5.3 */

CREATE CLASS HBMenuSys

   EXPORT:

   METHOD Modal( nSelection, nMsgRow, nMsgLeft, nMsgRight, cMsgColor, GetList )
   METHOD New( oMenu )

   PROTECTED:

   METHOD PushMenu()
   METHOD PopMenu()
   METHOD PopChild( nNewLevel )
   METHOD PopAll()
   METHOD Execute()
   METHOD MHitTest( oNewMenu, nNewLevel, nNewItem )
   METHOD ShowMsg( lMode )
   METHOD GetMsgArray()

   VAR oMenu
   VAR lOldMsgFlag
   VAR cOldMessage
   VAR aMenuList
   VAR nMenuLevel
   VAR nOldRow
   VAR nOldCol
   VAR nOldCursor
   VAR lMsgFlag
   VAR nMsgRow
   VAR nMsgLeft
   VAR nMsgRight
   VAR cMsgColor
   VAR cMsgSaveS

ENDCLASS

/***
*
*  Standard Menu System Modal handling for Menu Items
*
***/
METHOD Modal( nSelection, nMsgRow, nMsgLeft, nMsgRight, cMsgColor, GetList ) CLASS HBMenuSys

   LOCAL oTopMenu := ::oMenu

   LOCAL nReturn := 0

   LOCAL nKey
   LOCAL nNewItem
   LOCAL lLeftDown
   LOCAL oNewMenu
   LOCAL nNewLevel
   LOCAL nEvent
   LOCAL oMenuItem
   LOCAL nMenuItem
   LOCAL nTemp
   LOCAL bKeyBlock
   LOCAL lSubMenu

   ::nOldRow    := Row()  
   ::nOldCol    := Col()  
   ::nOldCursor := SetCursor( SC_NONE )  

   ::nMsgRow    := nMsgRow
   ::nMsgLeft   := nMsgLeft
   ::nMsgRight  := nMsgRight
   ::cMsgColor  := cMsgColor

   IF ( ::lMsgFlag := ISNUMBER( ::nMsgRow ) .AND. ;
                      ISNUMBER( ::nMsgLeft ) .AND. ;
                      ISNUMBER( ::nMsgRight ) )

      IF !ISCHARACTER( ::cMsgColor )
         ::cMsgColor := GetClrPair( SetColor(), 1 )
      ENDIF

      Scroll( ::nMsgRow, ::nMsgLeft, ::nMsgRow, ::nMsgRight )

      ::cMsgSaveS := SaveScreen( ::nMsgRow, ::nMsgLeft, ::nMsgRow, ::nMsgRight )

   ENDIF

   oTopMenu:Select( nSelection )

   IF !( oTopMenu:ClassName() == "TOPBARMENU" ) .AND. !oTopMenu:IsOpen
      oTopMenu:Open()
   ELSE
      oTopMenu:Display()
   ENDIF

   IF nSelection <= 0

      DO WHILE nSelection <= 0

         nEvent := Set( _SET_EVENTMASK, INKEY_KEYBOARD + INKEY_LDOWN )
         nKey := Inkey( 0 )
         Set( _SET_EVENTMASK, nEvent )

         IF nKey == K_LBUTTONDOWN .OR. nKey == K_LDBLCLK
            nSelection := oTopMenu:hitTest( MRow(), MCol() )

         ELSEIF ( nSelection := oTopMenu:getAccel( nKey ) ) != 0

         ELSEIF IsShortCut( oTopMenu, nKey, @nReturn )
            RETURN nReturn

         ELSE
            nSelection := 1

         ENDIF

      ENDDO

      oTopMenu:Select( nSelection )
      oTopMenu:Display()

   ENDIF

   IF !oTopMenu:GetItem( nSelection ):enabled
      RETURN 0
   ENDIF

   ::aMenuList      := Array( 16 )
   ::nMenuLevel     := 1
   ::aMenuList[ 1 ] := ::oMenu

   lLeftDown := MLeftDown()

   ::ShowMsg( .T. )

   DO WHILE .T.

      nKey := Inkey( 0 )

      IF ( bKeyBlock := SetKey( nKey ) ) != NIL
         Eval( bKeyBlock, ProcName( 1 ), ProcLine( 1 ), "" )
         LOOP
      ENDIF

      DO CASE
      CASE nKey == K_MOUSEMOVE

         IF lLeftDown

            IF !::MHitTest( @oNewMenu, @nNewLevel, @nNewItem ) // ; hit nowhere.

            ELSEIF nNewLevel != ::nMenuLevel // ; menu level change.

               IF nNewItem != oNewMenu:current .AND. oNewMenu:GetItem( nNewItem ):enabled
                  ::oMenu := oNewMenu
                  ::PopChild( nNewLevel )
                  ::oMenu:select( nNewItem )
                  ::oMenu:display()
                  ::PushMenu()
                  ::ShowMsg( .T. )
               ENDIF

            ELSEIF nNewItem != oNewMenu:Current() // ; menu item change.

               ::PopChild( ::nMenuLevel )

               IF ::oMenu:getItem( nNewItem ):enabled
                  ::oMenu:select( nNewItem )
                  ::oMenu:display()
                  ::PushMenu()
                  ::ShowMsg( .T. )
               ENDIF

            ENDIF

         ENDIF

      CASE nKey == K_DOWN

         IF ::oMenu:ClassName() == "TOPBARMENU"
            IF ::PushMenu()
               ::ShowMsg( .T. )
            ENDIF
         ELSE
            nTemp := ::oMenu:getNext()
            IF nTemp == 0
               nTemp := ::oMenu:getFirst()
            ENDIF
            ::oMenu:select( nTemp )
            ::oMenu:display()
            ::ShowMsg( .T. )
         ENDIF

      CASE nKey == K_UP

         IF !( ::oMenu:ClassName() == "TOPBARMENU" )
            nTemp := ::oMenu:getPrev()
            IF nTemp == 0
               nTemp := ::oMenu:getLast()
            ENDIF
            ::oMenu:select( nTemp )
            ::oMenu:display()
            ::ShowMsg( .T. )

         ENDIF

      CASE nKey == K_LEFT

         IF ( lSubMenu := ( ::nMenuLevel > 1 ) )
            ::PopMenu()
         ENDIF
         IF ::oMenu:ClassName() == "TOPBARMENU"
            nTemp := ::oMenu:getPrev()
            IF nTemp == 0
              nTemp := ::oMenu:getLast()
            ENDIF
            ::oMenu:select( nTemp )
            ::oMenu:display()
            IF lSubMenu
               ::PushMenu()
            ENDIF
         ENDIF
         ::ShowMsg( .T. )

      CASE nKey == K_RIGHT

         IF ( lSubMenu := ( ::nMenuLevel > 1 ) )
            ::PopMenu()
         ENDIF

         IF ::oMenu:ClassName() == "TOPBARMENU"
            nTemp := ::oMenu:getNext()
            IF nTemp == 0
               nTemp := ::oMenu:getFirst()
            ENDIF
            ::oMenu:select( nTemp )
            ::oMenu:display()
            IF lSubMenu
               ::PushMenu()
            ENDIF
         ENDIF
         ::ShowMsg( .T. )

      CASE nKey == K_ENTER

         IF ::PushMenu()
            ::ShowMsg( .T. )
         ELSE
            ::ShowMsg( .F. )
            nReturn := ::Execute()
            IF nReturn != 0
               EXIT
            ENDIF
         ENDIF

      CASE nKey == K_ESC // go to previous menu

         IF ::PopMenu()
            ::oMenu:display()
            ::ShowMsg( .T. )
         ELSE

            IF ::oMenu:ClassName() == "POPUPMENU"
               ::oMenu:close()
            ENDIF
            
            nReturn := -1 // Bail out if at the top menu item
            EXIT

         ENDIF

      CASE nKey == K_LBUTTONDOWN

         IF !::MHitTest( @oNewMenu, @nNewLevel, @nNewItem )

            IF GetList != NIL .AND. HitTest( GetList, MRow(), MCol(), ::GetMsgArray() ) != 0
               GetActive():ExitState := GE_MOUSEHIT
               __GetListActive():nLastExitState := GE_MOUSEHIT // Reset Get System values
               IF ::oMenu:ClassName() == "POPUPMENU"
                  ::PopMenu()
               ENDIF
               nReturn := -1
               EXIT
            ENDIF

            IF ::oMenu:ClassName() == "POPUPMENU"
               ::PopMenu()
            ENDIF

         ELSEIF nNewLevel == ::nMenuLevel
            ::oMenu:select( nNewItem )
            ::oMenu:display()
            ::PushMenu()
            ::ShowMsg( .T. )

         ELSE
            ::nMenuLevel := nNewLevel
            ::oMenu      := ::aMenuList[ ::nMenuLevel ]

            nMenuItem := ::oMenu:current
            oMenuItem := ::oMenu:getItem( nMenuItem )
            IF ( oMenuItem := ::oMenu:getItem( ::oMenu:Current ) ):isPopUp()
               oMenuItem:Data:Close()
            ENDIF

            IF nMenuItem != nNewItem
               nMenuItem := nNewItem
               ::oMenu:select( nNewItem )
               ::oMenu:display()
               ::PushMenu()
            ENDIF

            ::ShowMsg( .T. )
         ENDIF

         lLeftDown := .T.

      CASE nKey == K_LBUTTONUP

         lLeftDown := .F.

         IF ::MHitTest( @oNewMenu, @nNewLevel, @nNewItem ) .AND. ;
            nNewLevel == ::nMenuLevel

            IF nNewItem == ::oMenu:current
               ::ShowMsg( .F. )
               nReturn := ::Execute()
               IF nReturn != 0
                  EXIT
               ENDIF
            ENDIF
         ENDIF

      CASE ( nNewItem := ::oMenu:getAccel( nKey ) ) != 0

         IF ::oMenu:getItem( nNewItem ):enabled
            ::oMenu:select( nNewItem )
            ::oMenu:display()

            IF !::PushMenu()
               ::ShowMsg( .F. )
               nReturn := ::Execute()
               IF nReturn != 0
                  EXIT
               ENDIF
            ENDIF
            ::ShowMsg( .T. )

         ENDIF

      CASE IsShortCut( oTopMenu, nKey, @nReturn )

         IF nReturn != 0
            EXIT
         ENDIF

      CASE GetList != NIL .AND. ( nNewItem := Accelerator( GetList, nKey, ::GetMsgArray() ) ) != 0

         GetActive():ExitState := GE_SHORTCUT
         __GetListActive():nNextGet := nNewItem // Reset Get System values
         IF ::oMenu:ClassName() == "POPUPMENU"
            ::PopMenu()
         ENDIF

         nReturn := -1
         EXIT

      CASE ( nNewItem := oTopMenu:GetAccel( nKey ) ) != 0 // ; check for the top menu item accelerator key

         IF oTopMenu:GetItem( nNewItem ):enabled
            ::PopAll()
            ::oMenu:select( nNewItem )
            ::oMenu:display()
            IF oTopMenu:GetItem( nNewItem ):isPopUp()
               ::PushMenu()
            ELSE
               ::ShowMsg( .F. )
               nReturn := ::Execute()
               IF nReturn != 0
                  EXIT
               ENDIF
            ENDIF
            ::ShowMsg( .T. )
         ENDIF

      ENDCASE

   ENDDO

   IF ::lMsgFlag
      RestScreen( ::nMsgRow, ::nMsgLeft, ::nMsgRow, ::nMsgRight, ::cMsgSaveS )
   ENDIF

   ::PopAll()

   SetPos( ::nOldRow, ::nOldCol )
   SetCursor( ::nOldCursor )

   RETURN nReturn

/***
*
*  Increment ::nMenuLevel and optionally select first item.
*  If selected MenuItem IsPopUp, assign ::oMenu.
*
***/
METHOD PushMenu() CLASS HBMenuSys
   LOCAL oNewMenu := ::oMenu:getItem( ::oMenu:current )

   IF ISOBJECT( oNewMenu ) .AND. oNewMenu:IsPopUp

      ::oMenu := oNewMenu:Data
      ::aMenuList[ ++::nMenuLevel ] := ::oMenu
      ::oMenu:select( ::oMenu:getFirst() )

      IF !::oMenu:isOpen
         ::oMenu:open()
      ENDIF

      RETURN .T.

   ENDIF

   RETURN .F.

/***
*
*  Close SubMenuItem and Return to the upper MenuItem level.
*
***/
METHOD PopMenu() CLASS HBMenuSys

   IF ::nMenuLevel > 1
      ::oMenu:select( 0 )
      ::oMenu:close( .T. )
      ::oMenu := ::aMenuList[ --::nMenuLevel ] // Decrement MenuItem level and assign
      RETURN .T.
   ENDIF

   RETURN .F.

/***
*
*  Close PopUp Child MenuItem and Return to the upper MenuItem level.
*
***/
METHOD PopChild( nNewLevel ) CLASS HBMenuSys
   LOCAL oOldMenuItem
   LOCAL nCurrent

   IF ( nCurrent := ::oMenu:current ) != 0
      oOldMenuItem := ::oMenu:getItem( nCurrent )
      IF oOldMenuItem:IsPopUp
         oOldMenuItem:Data:Close()
         ::nMenuLevel := nNewLevel
         RETURN .T.
      ENDIF

   ENDIF

   RETURN .F.

/***
*
*  Close all Menus below Top Menu and Return to upper MenuItem level.
*
***/
METHOD PopAll() CLASS HBMenuSys

   IF ::aMenuList[ 2 ] != NIL
      ::aMenuList[ 2 ]:Close()
   ENDIF
   // Set the menu level and position relative to the top menu item:
   ::nMenuLevel := 1
   ::oMenu      := ::aMenuList[ 1 ]

   RETURN .T.

/***
*
*  Eval() the Data block if selected MenuItem is !IsPopUp.
*
***/
METHOD Execute() CLASS HBMenuSys
   LOCAL oNewMenu := ::oMenu:getItem( ::oMenu:current )
   LOCAL lPas := .T.

   // Execute the Data block if selected MenuItem is !IsPopUp:
   IF ISOBJECT( oNewMenu ) .AND. !oNewMenu:IsPopUp

      IF ::oMenu:ClassName() $ "TOPBARMENU|POPUPMENU"
         SetPos( ::nOldRow, ::nOldCol )
         SetCursor( ::nOldCursor )
         Eval( oNewMenu:Data, oNewMenu )
         SetCursor( SC_NONE )
         lPas := .F.
      ENDIF

      // Pop the Menu:
      ::oMenu:select( iif( ::PopMenu(), ::oMenu:current, 0 ) )

      // Display newly selected current menu item:
      IF ::oMenu:ClassName() == "POPUPMENU" .AND. ;
         ::nMenuLevel == 1 .AND. ;
         !::oMenu:isOpen

         ::oMenu:open()
      ENDIF

      IF lPas
         ::oMenu:close()
         SetPos( ::nOldRow, ::nOldCol )
         SetCursor( ::nOldCursor )
         Eval( oNewMenu:Data, oNewMenu )
         SetCursor( SC_NONE )
      ENDIF

      RETURN oNewMenu:Id

   ENDIF

   RETURN 0

/***
*
*  Test to find the Mouse location.
*  Note: Formal parameters received here were passed by reference.
*
***/
METHOD MHitTest( oNewMenu, nNewLevel, nNewItem ) CLASS HBMenuSys

   FOR nNewLevel := ::nMenuLevel TO 1 STEP -1
      oNewMenu   := ::aMenuList[ nNewLevel ]
      nNewItem   := oNewMenu:HitTest( MRow(), MCol() )
      IF nNewItem < 0
         // Test for the mouse on Menu separator or border
         RETURN .F.

      ELSEIF nNewItem > 0 .AND. oNewMenu:GetItem( nNewItem ):enabled
         // Test for the mouse on an enabled item in the menu
         RETURN .T.

      ENDIF

   NEXT

   RETURN .F.

/***
*
*  Erase and Show Messages.
*  Erase Message then ::ShowMsg() if lMode is .T.
*  Only erases Menu Message if lMode is .F.
*  SaveScreen()/RestScreen() is used for the
*  Message area in both text or graphics mode.
*
***/
METHOD ShowMsg( lMode ) CLASS HBMenuSys
   LOCAL nCurrent
   LOCAL cMsg
   LOCAL lMOldState := MSetCursor( .F. )

   IF ISLOGICAL( ::lOldMsgFlag ) .AND. ::lOldMsgFlag
      RestScreen( ::nMsgRow, ::nMsgLeft, ::nMsgRow, ::nMsgRight, ::cMsgSaveS )
   ENDIF

   IF lMode
      IF !ISCHARACTER( ::cMsgColor )
         ::cMsgColor := GetClrPair( SetColor(), 1 )
      ENDIF

      IF ::lMsgFlag .AND. ;
         ( nCurrent := ::oMenu:current ) != 0 .AND. ;
         !Empty( cMsg := ::oMenu:getItem( nCurrent ):message )

         DispOutAt( ::nMsgRow, ::nMsgLeft, PadC( cMsg, ::nMsgRight - ::nMsgLeft + 1 ), ::cMsgColor )
      ENDIF

      ::cOldMessage := cMsg
      ::lOldMsgFlag := ::lMsgFlag

   ENDIF

   MSetCursor( lMOldState )

   RETURN .T.

/* NOTE: Generates the somewhat internal, yet widely used message line format of CA-Cl*pper 5.3 
         This format contradicts the one in the official docs. */

METHOD GetMsgArray() CLASS HBMenuSys
   RETURN { , ::nMsgRow, ::nMsgLeft, ::nMsgRight, ::cMsgColor, , , , , }

/* -------------------------------------------- */

METHOD New( oMenu ) CLASS HBMenuSys
   ::oMenu := oMenu
   RETURN Self

#endif
