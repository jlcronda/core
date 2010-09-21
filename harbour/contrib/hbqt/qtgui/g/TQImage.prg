/*
 * $Id$
 */

/* -------------------------------------------------------------------- */
/* WARNING: Automatically generated source file. DO NOT EDIT!           */
/*          Instead, edit corresponding .qth file,                      */
/*          or the generator tool itself, and run regenarate.           */
/* -------------------------------------------------------------------- */

/*
 * Harbour Project source code:
 * QT wrapper main header
 *
 * Copyright 2009-2010 Pritpal Bedi <pritpal@vouchcac.com>
 *
 * Copyright 2009 Marcos Antonio Gambeta <marcosgambeta at gmail dot com>
 * www - http://harbour-project.org
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
/*----------------------------------------------------------------------*/


#include "hbclass.ch"


FUNCTION QImage( ... )
   RETURN HB_QImage():new( ... )


CREATE CLASS QImage INHERIT HbQtObjectHandler FUNCTION HB_QImage

   METHOD  new( ... )

   METHOD  allGray()
   METHOD  alphaChannel()
   METHOD  bits()
   METHOD  bits_1()
   METHOD  bytesPerLine()
   METHOD  cacheKey()
   METHOD  color( nI )
   METHOD  convertToFormat( nFormat, nFlags )
   METHOD  copy( ... )
   METHOD  createAlphaMask( nFlags )
   METHOD  createHeuristicMask( lClipTight )
   METHOD  createMaskFromColor( nColor, nMode )
   METHOD  depth()
   METHOD  dotsPerMeterX()
   METHOD  dotsPerMeterY()
   METHOD  fill( nPixelValue )
   METHOD  format()
   METHOD  hasAlphaChannel()
   METHOD  height()
   METHOD  invertPixels( nMode )
   METHOD  isGrayscale()
   METHOD  isNull()
   METHOD  load( ... )
   METHOD  loadFromData( pData, pFormat )
   METHOD  mirrored( lHorizontal, lVertical )
   METHOD  numBytes()
   METHOD  numColors()
   METHOD  offset()
   METHOD  pixel( ... )
   METHOD  pixelIndex( ... )
   METHOD  rect()
   METHOD  rgbSwapped()
   METHOD  save( ... )
   METHOD  scaled( ... )
   METHOD  scaledToHeight( nHeight, nMode )
   METHOD  scaledToWidth( nWidth, nMode )
   METHOD  scanLine( nI )
   METHOD  scanLine_1( nI )
   METHOD  setColor( nIndex, nColorValue )
   METHOD  setDotsPerMeterX( nX )
   METHOD  setDotsPerMeterY( nY )
   METHOD  setNumColors( nNumColors )
   METHOD  setOffset( pOffset )
   METHOD  setPixel( ... )
   METHOD  setText( cKey, cText )
   METHOD  size()
   METHOD  text( cKey )
   METHOD  textKeys()
   METHOD  transformed( ... )
   METHOD  valid( ... )
   METHOD  width()

   ENDCLASS


METHOD QImage:new( ... )
   LOCAL p
   FOR EACH p IN { ... }
      hb_pvalue( p:__enumIndex(), hbqt_ptr( p ) )
   NEXT
   ::pPtr := Qt_QImage( ... )
   RETURN Self


METHOD QImage:allGray()
   RETURN Qt_QImage_allGray( ::pPtr )


METHOD QImage:alphaChannel()
   RETURN Qt_QImage_alphaChannel( ::pPtr )


METHOD QImage:bits()
   RETURN Qt_QImage_bits( ::pPtr )


METHOD QImage:bits_1()
   RETURN Qt_QImage_bits_1( ::pPtr )


METHOD QImage:bytesPerLine()
   RETURN Qt_QImage_bytesPerLine( ::pPtr )


METHOD QImage:cacheKey()
   RETURN Qt_QImage_cacheKey( ::pPtr )


METHOD QImage:color( nI )
   RETURN Qt_QImage_color( ::pPtr, nI )


METHOD QImage:convertToFormat( nFormat, nFlags )
   RETURN Qt_QImage_convertToFormat( ::pPtr, nFormat, nFlags )


METHOD QImage:copy( ... )
   LOCAL p
   FOR EACH p IN { ... }
      hb_pvalue( p:__enumIndex(), hbqt_ptr( p ) )
   NEXT
   RETURN Qt_QImage_copy( ::pPtr, ... )


METHOD QImage:createAlphaMask( nFlags )
   RETURN Qt_QImage_createAlphaMask( ::pPtr, nFlags )


METHOD QImage:createHeuristicMask( lClipTight )
   RETURN Qt_QImage_createHeuristicMask( ::pPtr, lClipTight )


METHOD QImage:createMaskFromColor( nColor, nMode )
   RETURN Qt_QImage_createMaskFromColor( ::pPtr, nColor, nMode )


METHOD QImage:depth()
   RETURN Qt_QImage_depth( ::pPtr )


METHOD QImage:dotsPerMeterX()
   RETURN Qt_QImage_dotsPerMeterX( ::pPtr )


METHOD QImage:dotsPerMeterY()
   RETURN Qt_QImage_dotsPerMeterY( ::pPtr )


METHOD QImage:fill( nPixelValue )
   RETURN Qt_QImage_fill( ::pPtr, nPixelValue )


METHOD QImage:format()
   RETURN Qt_QImage_format( ::pPtr )


METHOD QImage:hasAlphaChannel()
   RETURN Qt_QImage_hasAlphaChannel( ::pPtr )


METHOD QImage:height()
   RETURN Qt_QImage_height( ::pPtr )


METHOD QImage:invertPixels( nMode )
   RETURN Qt_QImage_invertPixels( ::pPtr, nMode )


METHOD QImage:isGrayscale()
   RETURN Qt_QImage_isGrayscale( ::pPtr )


METHOD QImage:isNull()
   RETURN Qt_QImage_isNull( ::pPtr )


METHOD QImage:load( ... )
   LOCAL p
   FOR EACH p IN { ... }
      hb_pvalue( p:__enumIndex(), hbqt_ptr( p ) )
   NEXT
   RETURN Qt_QImage_load( ::pPtr, ... )


METHOD QImage:loadFromData( pData, pFormat )
   RETURN Qt_QImage_loadFromData( ::pPtr, hbqt_ptr( pData ), hbqt_ptr( pFormat ) )


METHOD QImage:mirrored( lHorizontal, lVertical )
   RETURN Qt_QImage_mirrored( ::pPtr, lHorizontal, lVertical )


METHOD QImage:numBytes()
   RETURN Qt_QImage_numBytes( ::pPtr )


METHOD QImage:numColors()
   RETURN Qt_QImage_numColors( ::pPtr )


METHOD QImage:offset()
   RETURN Qt_QImage_offset( ::pPtr )


METHOD QImage:pixel( ... )
   LOCAL p
   FOR EACH p IN { ... }
      hb_pvalue( p:__enumIndex(), hbqt_ptr( p ) )
   NEXT
   RETURN Qt_QImage_pixel( ::pPtr, ... )


METHOD QImage:pixelIndex( ... )
   LOCAL p
   FOR EACH p IN { ... }
      hb_pvalue( p:__enumIndex(), hbqt_ptr( p ) )
   NEXT
   RETURN Qt_QImage_pixelIndex( ::pPtr, ... )


METHOD QImage:rect()
   RETURN Qt_QImage_rect( ::pPtr )


METHOD QImage:rgbSwapped()
   RETURN Qt_QImage_rgbSwapped( ::pPtr )


METHOD QImage:save( ... )
   LOCAL p
   FOR EACH p IN { ... }
      hb_pvalue( p:__enumIndex(), hbqt_ptr( p ) )
   NEXT
   RETURN Qt_QImage_save( ::pPtr, ... )


METHOD QImage:scaled( ... )
   LOCAL p
   FOR EACH p IN { ... }
      hb_pvalue( p:__enumIndex(), hbqt_ptr( p ) )
   NEXT
   RETURN Qt_QImage_scaled( ::pPtr, ... )


METHOD QImage:scaledToHeight( nHeight, nMode )
   RETURN Qt_QImage_scaledToHeight( ::pPtr, nHeight, nMode )


METHOD QImage:scaledToWidth( nWidth, nMode )
   RETURN Qt_QImage_scaledToWidth( ::pPtr, nWidth, nMode )


METHOD QImage:scanLine( nI )
   RETURN Qt_QImage_scanLine( ::pPtr, nI )


METHOD QImage:scanLine_1( nI )
   RETURN Qt_QImage_scanLine_1( ::pPtr, nI )


METHOD QImage:setColor( nIndex, nColorValue )
   RETURN Qt_QImage_setColor( ::pPtr, nIndex, nColorValue )


METHOD QImage:setDotsPerMeterX( nX )
   RETURN Qt_QImage_setDotsPerMeterX( ::pPtr, nX )


METHOD QImage:setDotsPerMeterY( nY )
   RETURN Qt_QImage_setDotsPerMeterY( ::pPtr, nY )


METHOD QImage:setNumColors( nNumColors )
   RETURN Qt_QImage_setNumColors( ::pPtr, nNumColors )


METHOD QImage:setOffset( pOffset )
   RETURN Qt_QImage_setOffset( ::pPtr, hbqt_ptr( pOffset ) )


METHOD QImage:setPixel( ... )
   LOCAL p
   FOR EACH p IN { ... }
      hb_pvalue( p:__enumIndex(), hbqt_ptr( p ) )
   NEXT
   RETURN Qt_QImage_setPixel( ::pPtr, ... )


METHOD QImage:setText( cKey, cText )
   RETURN Qt_QImage_setText( ::pPtr, cKey, cText )


METHOD QImage:size()
   RETURN Qt_QImage_size( ::pPtr )


METHOD QImage:text( cKey )
   RETURN Qt_QImage_text( ::pPtr, cKey )


METHOD QImage:textKeys()
   RETURN Qt_QImage_textKeys( ::pPtr )


METHOD QImage:transformed( ... )
   LOCAL p
   FOR EACH p IN { ... }
      hb_pvalue( p:__enumIndex(), hbqt_ptr( p ) )
   NEXT
   RETURN Qt_QImage_transformed( ::pPtr, ... )


METHOD QImage:valid( ... )
   LOCAL p
   FOR EACH p IN { ... }
      hb_pvalue( p:__enumIndex(), hbqt_ptr( p ) )
   NEXT
   RETURN Qt_QImage_valid( ::pPtr, ... )


METHOD QImage:width()
   RETURN Qt_QImage_width( ::pPtr )

