%{
/*
 * $Id$
 */

/*
   Harbour Project source code

   YACC Rules and Actions

   Copyright 1999  Antonio Linares <alinares@fivetech.com>
   www - http://www.harbour-project.org

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version, with one exception:

   The exception is that if you link the Harbour Runtime Library (HRL)
   and/or the Harbour Virtual Machine (HVM) with other files to produce
   an executable, this does not by itself cause the resulting executable
   to be covered by the GNU General Public License. Your use of that
   executable is in no way restricted on account of linking the HRL
   and/or HVM code into it.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA (or visit
   their web site at http://www.gnu.org/).
*/

/* Harbour Project source code
   http://www.Harbour-Project.org/

   The following functions are Copyright 1999 Eddie Runia <eddie@runia.com>:
      Generation portable objects

   See doc/hdr_tpl.txt, Version 1.2 or later, for licensing terms.
*/

/* Compile using: bison -d -v harbour.y */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <malloc.h>     /* required for allocating and freeing memory */
#include <ctype.h>
#include <time.h>
#include "extend.h"
#include "pcode.h"      /* pcode values */
#include "compiler.h"
#include "hberrors.h"
#include "hbpp.h"
#include "hbver.h"

#define debug_msg( x, z )

extern FILE *yyin;      /* currently yacc parsed file */
extern int iLine;       /* currently parsed file line number */
  /* Following two lines added for preprocessor */
extern BOOL _bPPO;       /* flag indicating, is ppo output needed */
extern FILE *yyppo;     /* output .ppo file */

typedef struct          /* #include support */
{
   FILE * handle;       /* handle of the opened file */
   void * pBuffer;      /* buffer used by yacc */
   char * szFileName;   /* name of the file */
   void * pPrev;        /* pointer to the previous opened file */
   void * pNext;        /* pointer to the next opened file */
   int    iLine;        /* currently processed line number */
} _FILE, * PFILE;       /* structure to hold an opened PRG or CH */

typedef struct
{
   PFILE pLast;         /* pointer to the last opened file */
   int   iFiles;        /* number of files currently opened */
} FILES;                /* structure to control several opened PRGs and CHs */

int Include( char * szFileName, PATHNAMES * pSearchPath );  /* end #include support */

/* pcode chunks bytes size */
#define PCODE_CHUNK   100

typedef struct __ELSEIF
{
   ULONG ulOffset;
   struct __ELSEIF * pNext;
} _ELSEIF, * PELSEIF;      /* support structure for else if pcode fixups */

typedef struct _LOOPEXIT
{
   ULONG ulOffset;
   int iLine;
   struct _LOOPEXIT * pLoopList;
   struct _LOOPEXIT * pExitList;
   struct _LOOPEXIT * pNext;
} LOOPEXIT, * PTR_LOOPEXIT;  /* support structure for EXIT and LOOP statements */
static void LoopStart( void );
static void LoopEnd( void );
static void LoopLoop( void );
static void LoopExit( void );
static void LoopHere( void );

typedef struct __EXTERN
{
   char * szName;
   struct __EXTERN * pNext;
} _EXTERN, * PEXTERN;      /* support structure for extern symbols */
/* as they have to be placed on the symbol table later than the first public symbol */

/* Support for aliased expressions
 */
typedef struct _ALIASID
{
   char type;
   union {
      int iAlias;
      char * szAlias;
   } alias;
   struct _ALIASID * pPrev;
} ALIASID, *ALIASID_PTR;

#define  ALIAS_NUMBER   1
#define  ALIAS_NAME     2
#define  ALIAS_EVAL     3

static ULONG PackDateTime( void );

void AliasAddInt( int );
void AliasAddExp( void );
void AliasAddStr( char * );
void AliasPush( void );
void AliasPop( void );
void AliasSwap( void );
void AliasAdd( ALIASID_PTR );
void AliasRemove( void );

/* Support for parenthesized expressions
 */
typedef struct _EXPLIST
{
   BYTE * prevPCode;        /* pcode buffer used at the start of expression */
   ULONG prevSize;
   ULONG prevPos;
   BYTE * exprPCode;        /* pcode buffer for current expression */
   ULONG exprSize;
   struct _EXPLIST *pPrev;  /* previous expression in the list */
   struct _EXPLIST *pNext;  /* next expression in the list */
} EXPLIST, *EXPLIST_PTR;

void ExpListPush( void );  /* pushes the new expression on the stack */
void ExpListPop( int );    /* pops previous N expressions */

#ifdef __cplusplus
typedef struct yy_buffer_state *YY_BUFFER_STATE;
YY_BUFFER_STATE yy_create_buffer( FILE *, int ); /* yacc functions to manage multiple files */
void yy_switch_to_buffer( YY_BUFFER_STATE ); /* yacc functions to manage multiple files */
void yy_delete_buffer( YY_BUFFER_STATE ); /* yacc functions to manage multiple files */
#else
void * yy_create_buffer( FILE *, int ); /* yacc functions to manage multiple files */
void yy_switch_to_buffer( void * ); /* yacc functions to manage multiple files */
void yy_delete_buffer( void * ); /* yacc functions to manage multiple files */
#endif

/* lex & yacc related prototypes */
void yyerror( char * ); /* parsing error management function */
int yylex( void );      /* main lex token function, called by yyparse() */
int yyparse( void );    /* main yacc parsing function */
#ifdef __cplusplus
extern "C" int yywrap( void );
#else
int yywrap( void );     /* manages the EOF of current processed file */
#endif
  /* Following line added for preprocessor */
void Hbpp_init ( void );

/* production related functions */
PFUNCTION AddFunCall( char * szFuntionName );
void AddExtern( char * szExternName ); /* defines a new extern name */
void AddSearchPath( char *, PATHNAMES * * ); /* add pathname to a search list */
void AddVar( char * szVarName ); /* add a new param, local, static variable to a function definition or a public or private */
PCOMSYMBOL AddSymbol( char *, WORD * );
void CheckDuplVars( PVAR pVars, char * szVarName, int iVarScope ); /*checks for duplicate variables definitions */
void Dec( void );                  /* generates the pcode to decrement the latest value on the virtual machine stack */
void DimArray( int iDimensions ); /* instructs the virtual machine to build an array with wDimensions */
void Do( BYTE bParams );      /* generates the pcode to execute a Clipper function discarding its result */
void Duplicate( void ); /* duplicates the virtual machine latest stack latest value and places it on the stack */
void DupPCode( ULONG ulStart ); /* duplicates the current generated pcode from an offset */
void FieldPCode( BYTE , char * );      /* generates the pcode for database field */
void FixElseIfs( void * pIfElseIfs ); /* implements the ElseIfs pcode fixups */
void FixReturns( void ); /* fixes all last defined function returns jumps offsets */
void Function( BYTE bParams ); /* generates the pcode to execute a Clipper function pushing its result */
PFUNCTION FunctionNew( char *, char );  /* creates and initialises the _FUNC structure */
void FunDef( char * szFunName, SYMBOLSCOPE cScope, int iType ); /* starts a new Clipper language function definition */
void GenArray( int iElements ); /* instructs the virtual machine to build an array and load elemnst from the stack */
void GenBreak( void );  /* generate code for BREAK statement */
void * GenElseIf( void * pFirstElseIf, ULONG ulOffset ); /* generates a support structure for elseifs pcode fixups */
void GenExterns( void ); /* generates the symbols for the EXTERN names */
void GenIfInline( void ); /* generates pcodes for IIF( expr1, expr2, expr3 ) */
int GetFieldVarPos( char *, PFUNCTION * );   /* return if passed name is a field variable */
WORD GetVarPos( PVAR pVars, char * szVarName ); /* returns the order + 1 of a variable if defined or zero */
int GetLocalVarPos( char * szVarName ); /* returns the order + 1 of a local variable */
void Inc( void );                       /* generates the pcode to increment the latest value on the virtual machine stack */
ULONG Jump( LONG lOffset );                /* generates the pcode to jump to a specific offset */
ULONG JumpFalse( LONG lOffset );           /* generates the pcode to jump if false */
void JumpHere( ULONG ulOffset );             /* returns the pcode pos where to set a jump offset */
void JumpThere( ULONG ulFrom, ULONG ulTo ); /* sets a jump offset */
ULONG JumpTrue( LONG lOffset );            /* generates the pcode to jump if true */
void Line( void );                      /* generates the pcode with the currently compiled source code line */
void LineDebug( void );                 /* generates the pcode with the currently compiled source code line */
void LineBody( void );                  /* generates the pcode with the currently compiled source code line */
void VariablePCode( BYTE , char * );    /* generates the pcode for memvar variable */
void Message( char * szMsgName );       /* sends a message to an object */
void MessageFix( char * szMsgName );    /* fix a generated message to an object */
void MessageDupl( char * szMsgName );   /* fix a one generated message to an object and duplicate */
void PopId( char * szVarName );         /* generates the pcode to pop a value from the virtual machine stack onto a variable */
void PushDouble( double fNumber, BYTE bDec ); /* Pushes a number on the virtual machine stack */
void PushFunCall( char * );             /* generates the pcode to push function's call */
void PushId( char * szVarName );        /* generates the pcode to push a variable value to the virtual machine stack */
void PushIdByRef( char * szVarName );   /* generates the pcode to push a variable by reference to the virtual machine stack */
void PushInteger( int iNumber );        /* Pushes a integer number on the virtual machine stack */
void PushLogical( int iTrueFalse );     /* pushes a logical value on the virtual machine stack */
void PushLong( long lNumber );          /* Pushes a long number on the virtual machine stack */
void PushNil( void );                   /* Pushes nil on the virtual machine stack */
void PushString( char * szText );       /* Pushes a string on the virtual machine stack */
void PushSymbol( char * szSymbolName, int iIsFunction ); /* Pushes a symbol on to the Virtual machine stack */
void GenPCode1( BYTE );             /* generates 1 byte of pcode */
void GenPCode3( BYTE, BYTE, BYTE ); /* generates 3 bytes of pcode */
void GenPCodeN( BYTE * pBuffer, ULONG ulSize );  /* copy bytes to a pcode buffer */
char * SetData( char * szMsg );     /* generates an underscore-symbol name for a data assignment */
ULONG SequenceBegin( void );
ULONG SequenceEnd( void );
void SequenceFinish( ULONG, int );

/* support for FIELD declaration */
void FieldsSetAlias( char *, int );
int FieldsCount( void );

/* Codeblocks */
void CodeBlockStart( void );        /* starts a codeblock creation */
void CodeBlockEnd( void );          /* end of codeblock creation */

/* Static variables */
void StaticDefStart( void );
void StaticDefEnd( int );
void StaticAssign( void ); /* checks if static variable is initialized with function call */

/* output related functions */
extern void GenCCode( char *, char * );      /* generates the C language output */
extern void GenJava( char *, char * );       /* generates the Java language output */
extern void GenPascal( char *, char * );     /* generates the Pascal language output */
extern void GenRC( char *, char * );         /* generates the RC language output */
extern void GenPortObj( char *, char * );    /* generates the portable objects */
#ifdef HARBOUR_OBJ_GENERATION
extern void GenObj32( char *, char * );      /* generates OBJ 32 bits */
#endif

/* argument checking */
void CheckArgs( char *, int );

void PrintUsage( char * );

#define YYDEBUG        1    /* Parser debug information support */

typedef enum
{
   LANG_C,                  /* C language (by default) <file.c> */
   LANG_JAVA,               /* Java <file.java> */
   LANG_PASCAL,             /* Pascal <file.pas> */
   LANG_RESOURCES,          /* Resources <file.rc> */
   LANG_PORT_OBJ            /* Portable objects <file.hrb> */
} LANGUAGES;                /* supported Harbour output languages */

int iVarScope = VS_LOCAL;   /* holds the scope for next variables to be defined */
                            /* different values for iVarScope */

/* Table with parse errors */
char * _szCErrors[] =
{
   "Statement not allowed outside of procedure or function",
   "Redefinition of procedure or function: \'%s\'",
   "Duplicate variable declaration: \'%s\'",
   "%s declaration follows executable statement",
   "Outer codeblock variable is out of reach: \'%s\'",
   "Invalid numeric format '.'",
   "Unterminated string: \'%s\'",
   "Redefinition of predefined function %s: \'%s\'",
   "Illegal initializer: \'%s\'",
   "ENDIF does not match IF",
   "ENDDO does not match WHILE",
   "ENDCASE does not match DO CASE",
   "NEXT does not match FOR",
   "ELSE does not match IF",
   "ELSEIF does not match IF",
   "Syntax error: \'%s\'",
   "Unclosed control structures at line: %i",
   "%s statement with no loop in sight",
   "Syntax error: \'%s\' in: \'%s\'",
   "Incomplete statement: %s",
   "Incorrect number of arguments: %s %s",
   "Invalid lvalue",
   "Invalid use of \'@\' (pass by reference): \'%s\'",
   "Formal parameters already declared",
   "Invalid %s from within of SEQUENCE code",
   "Unterminated array index",
   "Memory allocation error",
   "Memory reallocation error",
   "Freeing a NULL memory pointer",
   "%s", /* YACC error messages */
   "Jump offset too long",
   "Can't create output file: \'%s\'",
   "Can't create preprocessed output file: \'%s\'",
   "Bad command line option: \'%s\'"
};

/* Table with parse warnings */
char * _szCWarnings[] =
{
   "Ambiguous reference: \'%s\'",
   "Ambiguous reference, assuming memvar: \'%s\'",
   "Variable: \'%s\' declared but not used in function: \'%s\'",
   "CodeBlock Parameter: \'%s\' declared but not used in function: \'%s\'",
   "Incompatible type in assignment to: \'%s\' expected: \'%s\'",
   "Incompatible operand type: \'%s\' expected: \'Logical\'",
   "Incompatible operand type: \'%s\' expected: \'Numeric\'",
   "Incompatible operand types: \'%s\' and: \'%s\'",
   "Suspicious type in assignment to: \'%s\' expected: \'%s\'",
   "Suspicious operand type: \'UnKnown\' expected: \'%s\'",
   "Suspicious operand type: \'UnKnown\' expected: \'Logical\'",
   "Suspicious operand type: \'UnKnown\' expected: \'Numeric\'"
};

/* Table with reserved functions names
 * NOTE: THIS TABLE MUST BE SORTED ALPHABETICALLY
*/
static const char * _szReservedFun[] = {
   "AADD"      ,
   "ABS"       ,
   "ASC"       ,
   "AT"        ,
   "BOF"       ,
   "BREAK"     ,
   "CDOW"      ,
   "CHR"       ,
   "CMONTH"    ,
   "COL"       ,
   "CTOD"      ,
   "DATE"      ,
   "DAY"       ,
   "DELETED"   ,
   "DEVPOS"    ,
   "DOW"       ,
   "DTOC"      ,
   "DTOS"      ,
   "EMPTY"     ,
   "EOF"       ,
   "EXP"       ,
   "FCOUNT"    ,
   "FIELDNAME" ,
   "FLOCK"     ,
   "FOUND"     ,
   "INKEY"     ,
   "INT"       ,
   "LASTREC"   ,
   "LEFT"      ,
   "LEN"       ,
   "LOCK"      ,
   "LOG"       ,
   "LOWER"     ,
   "LTRIM"     ,
   "MAX"       ,
   "MIN"       ,
   "MONTH"     ,
   "PCOL"      ,
   "PCOUNT"    ,
   "PROW"      ,
   "QSELF"     ,
   "RECCOUNT"  ,
   "RECNO"     ,
   "REPLICATE" ,
   "RLOCK"     ,
   "ROUND"     ,
   "ROW"       ,
   "RTRIM"     ,
   "SECONDS"   ,
   "SELECT"    ,
   "SETPOS"    ,
   "SETPOSBS"  ,
   "SPACE"     ,
   "SQRT"      ,
   "STR"       ,
   "SUBSTR"    ,
   "TIME"      ,
   "TRANSFORM" ,
   "TRIM"      ,
   "TYPE"      ,
   "UPPER"     ,
   "VAL"       ,
   "WORD"      ,
   "YEAR"
};
#define RESERVED_FUNCTIONS  sizeof( _szReservedFun ) / sizeof( char * )

static char * reserved_name( char * );

#define RESERVED_FUNC(szName) reserved_name( (szName) )

FILES files;
FUNCTIONS functions, funcalls;
PFUNCTION _pInitFunc;
SYMBOLS symbols;

/* /ES command line setting types */
#define HB_EXITLEVEL_DEFAULT    0
#define HB_EXITLEVEL_SETEXIT    1
#define HB_EXITLEVEL_DELTARGET  2

int iFunctions = 0;

BOOL _bStartProc = TRUE;                 /* holds if we need to create the starting procedure */
BOOL _bLineNumbers = TRUE;               /* holds if we need pcodes with line numbers */
BOOL _bLogo = TRUE;                      /* print logo */
BOOL _bQuiet = FALSE;                    /* quiet mode */
BOOL _bSyntaxCheckOnly = FALSE;          /* syntax check only */
int  _iLanguage = LANG_C;                /* default Harbour generated output language */
BOOL _bRestrictSymbolLength = FALSE;     /* generate 10 chars max symbols length */
BOOL _bShortCuts = TRUE;                 /* .and. & .or. expressions shortcuts */
BOOL _bWarnings = FALSE;                 /* enable parse warnings */
BOOL _bAnyWarning = FALSE;               /* holds if there was any warning during the compilation process */
BOOL _bAutoMemvarAssume = FALSE;         /* holds if undeclared variables are automatically assumed MEMVAR */
BOOL _bForceMemvars = FALSE;             /* holds if memvars are assumed when accesing undeclared variable */
BOOL _bDebugInfo = FALSE;                /* holds if generate debugger required info */
char _szPrefix[ 20 ] = { '\0' };         /* holds the prefix added to the generated symbol init function name (in C output currently) */
int  _iExitLevel = HB_EXITLEVEL_DEFAULT; /* holds if there was any warning during the compilation process */

/* This variable is used to flag if variables have to be passed by reference
 * - it is required in DO <proc> WITH <params> statement
 * For example:
 * DO proces WITH aVar, bVar:=cVar
 *  aVar - have to be passed by reference
 *  bVar and cBar - have to be passed by value
 */
BOOL _bForceByRefer = FALSE;
/* This variable is true if the right value of assignment will be build.
 * It is used to temporarily cancel the above _bForceByRefer
 */
BOOL _bRValue       = FALSE;

WORD _wSeqCounter   = 0;
WORD _wForCounter   = 0;
WORD _wIfCounter    = 0;
WORD _wWhileCounter = 0;
WORD _wCaseCounter  = 0;
ULONG _ulMessageFix = 0;  /* Position of the message which needs to be changed */
#ifdef HARBOUR_OBJ_GENERATION
BOOL _bObj32 = FALSE;     /* generate OBJ 32 bits */
#endif
int _iStatics = 0;       /* number of defined statics variables on the PRG */
PEXTERN pExterns = NULL;
PTR_LOOPEXIT pLoops = NULL;
PATHNAMES *_pIncludePath = NULL;
PHB_FNAME _pFileName = NULL;
ALIASID_PTR pAliasId = NULL;
ULONG _ulLastLinePos = 0;    /* position of last opcode with line number */
BOOL _bDontGenLineNum = FALSE;   /* suppress line number generation */

EXPLIST_PTR _pExpList = NULL;    /* stack used for parenthesized expressions */

PSTACK_VAL_TYPE pStackValType = NULL; /* compile time stack values linked list */
char cVarType = ' ';               /* current declared variable type */

#define LOOKUP 0
extern int _iState;     /* current parser state (defined in harbour.l */
%}

%union                  /* special structure used by lex and yacc to share info */
{
   char * string;       /* to hold a string returned by lex */
   int    iNumber;      /* to hold a number returned by lex */
   long   lNumber;      /* to hold a long number returned by lex */
   struct
   {
      double dNumber;   /* to hold a double number returned by lex */
      /* NOTE: Intentionally using "unsigned char" instead of "BYTE" */
      unsigned char bDec; /* to hold the number of decimal points in the value */
   } dNum;
   void * pVoid;        /* to hold any memory structure we may need */
};

%token FUNCTION PROCEDURE IDENTIFIER RETURN NIL DOUBLE INASSIGN INTEGER INTLONG
%token LOCAL STATIC IIF IF ELSE ELSEIF END ENDIF LITERAL TRUEVALUE FALSEVALUE
%token EXTERN INIT EXIT AND OR NOT PUBLIC EQ NE1 NE2
%token INC DEC ALIAS DOCASE CASE OTHERWISE ENDCASE ENDDO MEMVAR
%token WHILE EXIT LOOP END FOR NEXT TO STEP LE GE FIELD IN PARAMETERS
%token PLUSEQ MINUSEQ MULTEQ DIVEQ POWER EXPEQ MODEQ EXITLOOP
%token PRIVATE BEGINSEQ BREAK RECOVER USING DO WITH SELF LINE
%token AS_NUMERIC AS_CHARACTER AS_LOGICAL AS_DATE AS_ARRAY AS_BLOCK AS_OBJECT DECLARE_FUN

/*the lowest precedence*/
/*postincrement and postdecrement*/
%left  POST
/*assigment - from right to left*/
%right INASSIGN
%left  PLUSEQ MINUSEQ
%left  MULTEQ DIVEQ MODEQ
%left  EXPEQ
/*logical operators*/
%left  OR
%left  AND
%left  NOT
/*relational operators*/
%left  '<' '>' EQ NE1 NE2 LE GE '$'
/*mathematical operators*/
%left  '+' '-'
%left  '*' '/' '%'
%left  POWER
%left  UNARY
/*preincrement and predecrement*/
%left  PRE
/*special operators*/
%left  ALIAS '&' '@' ')'
%right '\n' ';' ',' '='
/*the highest precedence*/

%type <string>  IDENTIFIER LITERAL FunStart MethStart IdSend ObjectData AliasVar
%type <dNum>    DOUBLE
%type <iNumber> ArgList ElemList PareExpList ExpList FunCall FunScope IncDec
%type <iNumber> Params ParamList Logical ArrExpList
%type <iNumber> INTEGER BlockExpList Argument IfBegin VarId VarList MethParams ObjFunCall
%type <iNumber> MethCall BlockList FieldList DoArgList VarAt
%type <lNumber> INTLONG WhileBegin BlockBegin
%type <pVoid>   IfElseIf Cases

%%

Main       : { Line(); } Source       {
                                         FixReturns();       /* fix all previous function returns offsets */
                                         if( ! _bQuiet )
                                            printf( "\rLines %i, Functions %i\n", iLine, iFunctions );
                                      }

Source     : Crlf
           | VarDefs
           | FieldsDef
           | MemvarDef
           | Function
           | Statement
           | Line
           | Source Crlf
           | Source Function
           | Source { LineBody(); } Statement
           | Source VarDefs
           | Source FieldsDef
           | Source MemvarDef
           | Source Line
           ;

Line       : LINE INTEGER LITERAL Crlf
           | LINE INTEGER LITERAL '@' LITERAL Crlf   /* XBase++ style */
           ;

Function   : FunScope FUNCTION  IDENTIFIER { cVarType = ' '; FunDef( $3, ( SYMBOLSCOPE ) $1, 0 ); } Params Crlf {}
           | FunScope PROCEDURE IDENTIFIER { cVarType = ' '; FunDef( $3, ( SYMBOLSCOPE ) $1, FUN_PROCEDURE ); } Params Crlf {}
           | FunScope DECLARE_FUN IDENTIFIER Params              Crlf { cVarType = ' '; AddSymbol( $3, NULL ); }
           | FunScope DECLARE_FUN IDENTIFIER Params AS_NUMERIC   Crlf { cVarType = 'N'; AddSymbol( $3, NULL ); }
           | FunScope DECLARE_FUN IDENTIFIER Params AS_CHARACTER Crlf { cVarType = 'C'; AddSymbol( $3, NULL ); }
           | FunScope DECLARE_FUN IDENTIFIER Params AS_DATE      Crlf { cVarType = 'D'; AddSymbol( $3, NULL ); }
           | FunScope DECLARE_FUN IDENTIFIER Params AS_LOGICAL   Crlf { cVarType = 'L'; AddSymbol( $3, NULL ); }
           | FunScope DECLARE_FUN IDENTIFIER Params AS_ARRAY     Crlf { cVarType = 'A'; AddSymbol( $3, NULL ); }
           | FunScope DECLARE_FUN IDENTIFIER Params AS_OBJECT    Crlf { cVarType = 'O'; AddSymbol( $3, NULL ); }
           | FunScope DECLARE_FUN IDENTIFIER Params AS_BLOCK     Crlf { cVarType = 'B'; AddSymbol( $3, NULL ); }
           ;

FunScope   :                  { $$ = FS_PUBLIC; }
           | STATIC           { $$ = FS_STATIC; }
           | INIT             { $$ = FS_INIT; }
           | EXIT             { $$ = FS_EXIT; }
           ;

Params     :                                               { $$ = 0; }
           | '(' ')'                                       { $$ = 0; }
           | '(' { iVarScope = VS_PARAMETER; } ParamList ')'   { $$ = $3; }
           ;

ParamList  : IDENTIFIER                    { cVarType = ' '; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_NUMERIC         { cVarType = 'N'; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_CHARACTER       { cVarType = 'C'; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_DATE            { cVarType = 'D'; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_LOGICAL         { cVarType = 'L'; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_ARRAY           { cVarType = 'A'; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_BLOCK           { cVarType = 'B'; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_OBJECT          { cVarType = 'O'; AddVar( $1 ); $$ = 1; }
           | ParamList ',' IDENTIFIER      { AddVar( $3 ); $$++; }
           ;

Statements : Statement
           | Statements { Line(); } Statement
           ;

Statement  : ExecFlow Crlf        {}
           | FunCall Crlf         { Do( $1 ); }
           | AliasFunc Crlf       {}
           | IfInline Crlf        { GenPCode1( HB_P_POP ); }
           | ObjectMethod Crlf    { GenPCode1( HB_P_POP ); }
           | VarUnary Crlf        { GenPCode1( HB_P_POP ); }
           | VarAssign Crlf       { GenPCode1( HB_P_POP ); _bRValue = FALSE; }

           | IDENTIFIER '=' Expression Crlf            { PopId( $1 ); }
           | AliasVar '=' { $<pVoid>$=( void * )pAliasId; pAliasId = NULL; } Expression Crlf  { pAliasId=(ALIASID_PTR) $<pVoid>3; PopId( $1 ); AliasRemove(); }
           | AliasFunc '=' Expression Crlf             { --iLine; GenError( _szCErrors, 'E', ERR_INVALID_LVALUE, NULL, NULL ); }
           | VarAt '=' Expression Crlf                 { GenPCode1( HB_P_ARRAYPUT ); GenPCode1( HB_P_POP ); }
           | FunCallArray '=' Expression Crlf          { GenPCode1( HB_P_ARRAYPUT ); GenPCode1( HB_P_POP ); }
           | ObjectData '=' { MessageFix( SetData( $1 ) ); } Expression Crlf { Function( 1 ); GenPCode1( HB_P_POP ); }
           | ObjectData ArrayIndex '=' Expression Crlf    { GenPCode1( HB_P_ARRAYPUT ); GenPCode1( HB_P_POP ); }
           | ObjectMethod ArrayIndex '=' Expression Crlf  { GenPCode1( HB_P_ARRAYPUT ); GenPCode1( HB_P_POP ); }

           | BREAK { GenBreak(); } Crlf               { Do( 0 ); }
           | BREAK { GenBreak(); } Expression Crlf    { Do( 1 ); }
           | RETURN Crlf              { if( _wSeqCounter ) GenError( _szCErrors, 'E', ERR_EXIT_IN_SEQUENCE, "RETURN", NULL ); GenPCode1( HB_P_ENDPROC ); }
           | RETURN Expression Crlf   { if( _wSeqCounter ) GenError( _szCErrors, 'E', ERR_EXIT_IN_SEQUENCE, "RETURN", NULL ); GenPCode1( HB_P_RETVALUE ); GenPCode1( HB_P_ENDPROC ); }
           | PUBLIC { iVarScope = VS_PUBLIC; } VarList Crlf
           | PRIVATE { iVarScope = VS_PRIVATE; } VarList Crlf

           | EXITLOOP Crlf            { LoopExit(); }
           | LOOP Crlf                { LoopLoop(); }
           | DoProc Crlf
           | EXTERN ExtList Crlf
           ;

ExtList    : IDENTIFIER                               { AddExtern( $1 ); }
           | ExtList ',' IDENTIFIER                   { AddExtern( $3 ); }
           ;

FunCall    : FunStart ')'                { $$=0; CheckArgs( $1, $$ ); }
           | FunStart ArgList ')'        { $$=$2; CheckArgs( $1, $$ ); }
           ;

FunStart   : IDENTIFIER '('              { StaticAssign(); PushFunCall( $1 ); $$ = $1; }
           ;

MethCall   : MethStart ')'               { $$ = 0; }
           | MethStart ArgList ')'       { $$ = $2; }
           ;

MethStart  : IDENTIFIER '('              { StaticAssign(); Message( $1 ); $$ = $1; }
           ;

ArgList    : ','                               { PushNil(); PushNil(); $$ = 2; }
           | Argument                          { $$ = 1; }
           | ArgList ','                       { PushNil(); $$++; }
           | ArgList ',' Argument              { $$++; }
           | ','                               { PushNil(); } Argument { $$ = 2; }
           ;

Argument   : Expression                        {}
           | '@' IDENTIFIER                    { PushIdByRef( $2 ); }
           | '@' IDENTIFIER '(' ')'            { PushSymbol( $2, 1 ); GenPCode1( HB_P_FUNCPTR ); }
           ;

MethParams : /* empty */                       { $$ = 0; }
           | ArgList                           { $$ = $1; }
           ;

ObjectData : IdSend IDENTIFIER                     { $$ = $2; _ulMessageFix = functions.pLast->lPCodePos; Message( $2 ); Function( 0 ); }
           | VarAt ':' IDENTIFIER                  { GenPCode1( HB_P_ARRAYAT ); $$ = $3; _ulMessageFix = functions.pLast->lPCodePos; Message( $3 ); Function( 0 ); }
           | ObjFunCall IDENTIFIER                 { $$ = $2; _ulMessageFix = functions.pLast->lPCodePos; Message( $2 ); Function( 0 ); }
           | ObjFunArray  ':' IDENTIFIER           { $$ = $3; _ulMessageFix = functions.pLast->lPCodePos; Message( $3 ); Function( 0 ); }
           | ObjectMethod ':' IDENTIFIER           { $$ = $3; _ulMessageFix = functions.pLast->lPCodePos; Message( $3 ); Function( 0 ); }
           | ObjectData   ':' IDENTIFIER           { $$ = $3; _ulMessageFix = functions.pLast->lPCodePos; Message( $3 ); Function( 0 ); }
           | ObjectData ArrayIndex ':' IDENTIFIER  { GenPCode1( HB_P_ARRAYAT ); $$ = $4; _ulMessageFix = functions.pLast->lPCodePos; Message( $4 ); Function( 0 ); }
           ;

ObjectMethod : IdSend IDENTIFIER { Message( $2 ); } '(' MethParams ')' { Function( $5 ); }
           | VarAt ':' MethCall { Function( $3 ); GenPCode1( HB_P_ARRAYAT ); }
           | ObjFunCall MethCall                   { Function( $2 ); }
           | ObjFunArray  ':' MethCall             { Function( $3 ); }
           | ObjectData   ':' MethCall             { Function( $3 ); }
           | ObjectData ArrayIndex ':' MethCall { Function( $4 ); { GenPCode1( HB_P_ARRAYAT ); } }
           | ObjectMethod ':' MethCall             { Function( $3 ); }
           ;

IdSend     : IDENTIFIER ':'                       { PushId( $1 ); $$ = $1; }
           ;

ObjFunCall : FunCall ':'                      { Function( $1 ); $$ = $1; }
           ;

FunCallArray : FunCall { Function( $1 ); } ArrayIndex
           ;

ObjFunArray : FunCallArray ':' { GenPCode1( HB_P_ARRAYAT ); }
           ;

NumExpression : DOUBLE                        { PushDouble( $1.dNumber,$1.bDec ); }
           | INTEGER                          { PushInteger( $1 ); }
           | INTLONG                          { PushLong( $1 ); }
           ;

ConExpression : NIL                           { PushNil(); }
           | LITERAL                          { PushString( $1 ); }
           | CodeBlock                        {}
           | Logical                          { PushLogical( $1 ); }
           ;

DynExpression : Variable
           | VarUnary
           | Operators                        {}
           | FunCall                          { Function( $1 ); }
           | IfInline                         {}
           | Array                            {}
           | ObjectMethod                     {}
           | Macro                            {}
           | AliasVar                         { PushId( $1 ); AliasRemove(); }
           | AliasFunc                        {}
           | SELF                             { GenPCode1( HB_P_PUSHSELF ); }
           ;

SimpleExpression : NumExpression
           | ConExpression
           | DynExpression
           ;

Expression : SimpleExpression       {}
           | PareExpList            {}
           ;

EmptyExpression: /* nothing => nil */
           | Expression
           ;

IfInline   : IIF PareExpList3       { GenIfInline(); }
           | IF  PareExpList3       { GenIfInline(); }
           ;

Macro      : '&' Variable
           | '&' '(' Expression ')'
           ;

AliasVar   : INTEGER ALIAS { AliasAddInt( $1 ); } IDENTIFIER  { $$ = $4; }
           | IDENTIFIER ALIAS { AliasAddStr( $1 ); } IDENTIFIER  { $$ = $4; }
           | PareExpList ALIAS { AliasAddExp(); } IDENTIFIER  { $$ = $4; }
           ;

/* NOTE: In the case:
 * alias->( Expression )
 * alias always selects a workarea even if it is MEMVAR or M
 */
AliasFunc  : INTEGER ALIAS { AliasPush(); PushInteger( $1 ); AliasPop(); } PareExpList { AliasSwap(); }
           | IDENTIFIER ALIAS { AliasPush(); PushSymbol( $1, 0 ); AliasPop(); } PareExpList   { AliasSwap(); }
           | PareExpList ALIAS { AliasPush(); AliasSwap(); } PareExpList  { AliasSwap(); }
           ;

VarUnary   : IDENTIFIER IncDec %prec POST    { PushId( $1 ); Duplicate(); $2 ? Inc(): Dec(); PopId( $1 ); }
           | IncDec IDENTIFIER %prec PRE     { PushId( $2 ); $1 ? Inc(): Dec(); Duplicate(); PopId( $2 ); }
           | VarAt IncDec %prec POST { DupPCode( $1 ); GenPCode1( HB_P_ARRAYAT ); $2 ? Inc(): Dec(); GenPCode1( HB_P_ARRAYPUT ); $2 ? Dec(): Inc(); }
           | IncDec VarAt %prec PRE  { DupPCode( $2 ); GenPCode1( HB_P_ARRAYAT ); $1 ? Inc(): Dec(); GenPCode1( HB_P_ARRAYPUT ); }
           | FunCallArray IncDec %prec POST { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); $2 ? Inc(): Dec(); GenPCode1( HB_P_ARRAYPUT ); $2 ? Dec(): Inc(); }
           | IncDec FunCallArray %prec PRE  { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); $1 ? Inc(): Dec(); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectData IncDec %prec POST   { MessageDupl( SetData( $1 ) ); Function( 0 ); $2 ? Inc(): Dec(); Function( 1 ); $2 ? Dec(): Inc(); }
           | IncDec ObjectData %prec PRE    { MessageDupl( SetData( $2 ) ); Function( 0 ); $1 ? Inc(): Dec(); Function( 1 ); }
           | ObjectData ArrayIndex IncDec %prec POST { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); $3 ? Inc(): Dec(); GenPCode1( HB_P_ARRAYPUT ); $3 ? Dec(): Inc(); }
           | IncDec ObjectData ArrayIndex %prec PRE  { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); $1 ? Inc(): Dec(); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectMethod ArrayIndex IncDec %prec POST { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); $3 ? Inc(): Dec(); GenPCode1( HB_P_ARRAYPUT ); $3 ? Dec(): Inc(); }
           | IncDec ObjectMethod ArrayIndex %prec PRE  { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); $1 ? Inc(): Dec(); GenPCode1( HB_P_ARRAYPUT ); }
           | AliasVar IncDec %prec POST    { PushId( $1 ); Duplicate(); $2 ? Inc(): Dec(); PopId( $1 ); AliasRemove(); }
           | IncDec AliasVar %prec PRE     { PushId( $2 ); $1 ? Inc(): Dec(); Duplicate(); PopId( $2 ); AliasRemove(); }
           ;

IncDec     : INC                             { $$ = 1; }
           | DEC                             { $$ = 0; }
           ;

Variable   : VarId                     {}
           | VarAt                     { GenPCode1( HB_P_ARRAYAT ); }
           | FunCallArray              { GenPCode1( HB_P_ARRAYAT ); }
           | ObjectData                {}
           | ObjectData ArrayIndex     { GenPCode1( HB_P_ARRAYAT ); }
           | ObjectMethod ArrayIndex   { GenPCode1( HB_P_ARRAYAT ); }
           ;

VarId      : IDENTIFIER        { $$ = functions.pLast->lPCodePos;
                                 if( _bForceByRefer && functions.pLast->szName && ! _bRValue )
                                    /* DO .. WITH uses reference to a variable
                                     * if not inside a codeblock
                                     */
                                    PushIdByRef( $1 );
                                 else
                                    PushId( $1 );
                               }
           ;

VarAt      : IDENTIFIER { $<iNumber>$ = functions.pLast->lPCodePos; PushId( $1 ); } ArrayIndex { $$ =$<iNumber>2;  }
           ;

ArrayIndex : '[' IndexList ']'
           | ArrayIndex { GenPCode1( HB_P_ARRAYAT ); } '[' IndexList ']'
           ;

IndexList  : Expression
           | IndexList { GenPCode1( HB_P_ARRAYAT ); } ',' Expression
           ;

/*NOTE: If _bRValue is TRUE then the expression is on the right side of assignment
 * operator (or +=, -= ...) - in this case a variable is not pushed by
 * a reference it is a part of DO <proc> WITH ... statement
 */
VarAssign  : IDENTIFIER INASSIGN { _bRValue = TRUE; } Expression { PopId( $1 ); PushId( $1 ); }
           | IDENTIFIER PLUSEQ   { PushId( $1 ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_PLUS    ); PopId( $1 ); PushId( $1 ); }
           | IDENTIFIER MINUSEQ  { PushId( $1 ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MINUS   ); PopId( $1 ); PushId( $1 ); }
           | IDENTIFIER MULTEQ   { PushId( $1 ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MULT    ); PopId( $1 ); PushId( $1 ); }
           | IDENTIFIER DIVEQ    { PushId( $1 ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_DIVIDE  ); PopId( $1 ); PushId( $1 ); }
           | IDENTIFIER EXPEQ    { PushId( $1 ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_POWER   ); PopId( $1 ); PushId( $1 ); }
           | IDENTIFIER MODEQ    { PushId( $1 ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MODULUS ); PopId( $1 ); PushId( $1 ); }
           | VarAt INASSIGN { _bRValue = TRUE; } Expression { GenPCode1( HB_P_ARRAYPUT ); }
           | VarAt PLUSEQ   { DupPCode( $1 ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_PLUS    ); GenPCode1( HB_P_ARRAYPUT ); }
           | VarAt MINUSEQ  { DupPCode( $1 ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MINUS   ); GenPCode1( HB_P_ARRAYPUT ); }
           | VarAt MULTEQ   { DupPCode( $1 ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MULT    ); GenPCode1( HB_P_ARRAYPUT ); }
           | VarAt DIVEQ    { DupPCode( $1 ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_DIVIDE  ); GenPCode1( HB_P_ARRAYPUT ); }
           | VarAt EXPEQ    { DupPCode( $1 ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_POWER   ); GenPCode1( HB_P_ARRAYPUT ); }
           | VarAt MODEQ    { DupPCode( $1 ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MODULUS ); GenPCode1( HB_P_ARRAYPUT ); }
           | FunCallArray INASSIGN { _bRValue = TRUE; } Expression { GenPCode1( HB_P_ARRAYPUT ); }
           | FunCallArray PLUSEQ   { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; }  Expression { GenPCode1( HB_P_PLUS    ); GenPCode1( HB_P_ARRAYPUT ); }
           | FunCallArray MINUSEQ  { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; }  Expression { GenPCode1( HB_P_MINUS   ); GenPCode1( HB_P_ARRAYPUT ); }
           | FunCallArray MULTEQ   { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; }  Expression { GenPCode1( HB_P_MULT    ); GenPCode1( HB_P_ARRAYPUT ); }
           | FunCallArray DIVEQ    { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; }  Expression { GenPCode1( HB_P_DIVIDE  ); GenPCode1( HB_P_ARRAYPUT ); }
           | FunCallArray EXPEQ    { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; }  Expression { GenPCode1( HB_P_POWER   ); GenPCode1( HB_P_ARRAYPUT ); }
           | FunCallArray MODEQ    { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; }  Expression { GenPCode1( HB_P_MODULUS ); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectData INASSIGN { MessageFix ( SetData( $1 ) ); _bRValue = TRUE; } Expression { Function( 1 ); }
           | ObjectData PLUSEQ   { MessageDupl( SetData( $1 ) ); Function( 0 ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_PLUS );    Function( 1 ); }
           | ObjectData MINUSEQ  { MessageDupl( SetData( $1 ) ); Function( 0 ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MINUS );   Function( 1 ); }
           | ObjectData MULTEQ   { MessageDupl( SetData( $1 ) ); Function( 0 ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MULT );    Function( 1 ); }
           | ObjectData DIVEQ    { MessageDupl( SetData( $1 ) ); Function( 0 ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_DIVIDE );  Function( 1 ); }
           | ObjectData EXPEQ    { MessageDupl( SetData( $1 ) ); Function( 0 ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_POWER );   Function( 1 ); }
           | ObjectData MODEQ    { MessageDupl( SetData( $1 ) ); Function( 0 ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MODULUS ); Function( 1 ); }
           | ObjectData ArrayIndex INASSIGN { _bRValue = TRUE; } Expression      { GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectData ArrayIndex PLUSEQ   { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_PLUS    ); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectData ArrayIndex MINUSEQ  { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MINUS   ); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectData ArrayIndex MULTEQ   { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MULT    ); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectData ArrayIndex DIVEQ    { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_DIVIDE  ); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectData ArrayIndex EXPEQ    { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_POWER   ); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectData ArrayIndex MODEQ    { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MODULUS ); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectMethod ArrayIndex INASSIGN { _bRValue = TRUE; } Expression    { GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectMethod ArrayIndex PLUSEQ   { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_PLUS    ); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectMethod ArrayIndex MINUSEQ  { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MINUS   ); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectMethod ArrayIndex MULTEQ   { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MULT    ); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectMethod ArrayIndex DIVEQ    { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_DIVIDE  ); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectMethod ArrayIndex EXPEQ    { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_POWER   ); GenPCode1( HB_P_ARRAYPUT ); }
           | ObjectMethod ArrayIndex MODEQ    { GenPCode1( HB_P_DUPLTWO ); GenPCode1( HB_P_ARRAYAT ); _bRValue = TRUE; } Expression { GenPCode1( HB_P_MODULUS ); GenPCode1( HB_P_ARRAYPUT ); }
           | AliasVar INASSIGN { _bRValue = TRUE; $<pVoid>$=( void * ) pAliasId; pAliasId = NULL; } Expression { pAliasId=(ALIASID_PTR) $<pVoid>3; PopId( $1 ); PushId( $1 ); AliasRemove(); }
           | AliasVar PLUSEQ   { PushId( $1 ); _bRValue = TRUE; $<pVoid>$=(void*)pAliasId; pAliasId = NULL; } Expression { GenPCode1( HB_P_PLUS    ); pAliasId=(ALIASID_PTR) $<pVoid>3; PopId( $1 ); PushId( $1 ); AliasRemove(); }
           | AliasVar MINUSEQ  { PushId( $1 ); _bRValue = TRUE; $<pVoid>$=(void*)pAliasId; pAliasId = NULL; } Expression { GenPCode1( HB_P_MINUS   ); pAliasId=(ALIASID_PTR) $<pVoid>3; PopId( $1 ); PushId( $1 ); AliasRemove(); }
           | AliasVar MULTEQ   { PushId( $1 ); _bRValue = TRUE; $<pVoid>$=(void*)pAliasId; pAliasId = NULL; } Expression { GenPCode1( HB_P_MULT    ); pAliasId=(ALIASID_PTR) $<pVoid>3; PopId( $1 ); PushId( $1 ); AliasRemove(); }
           | AliasVar DIVEQ    { PushId( $1 ); _bRValue = TRUE; $<pVoid>$=(void*)pAliasId; pAliasId = NULL; } Expression { GenPCode1( HB_P_DIVIDE  ); pAliasId=(ALIASID_PTR) $<pVoid>3; PopId( $1 ); PushId( $1 ); AliasRemove(); }
           | AliasVar EXPEQ    { PushId( $1 ); _bRValue = TRUE; $<pVoid>$=(void*)pAliasId; pAliasId = NULL; } Expression { GenPCode1( HB_P_POWER   ); pAliasId=(ALIASID_PTR) $<pVoid>3; PopId( $1 ); PushId( $1 ); AliasRemove(); }
           | AliasVar MODEQ    { PushId( $1 ); _bRValue = TRUE; $<pVoid>$=(void*)pAliasId; pAliasId = NULL; } Expression { GenPCode1( HB_P_MODULUS ); pAliasId=(ALIASID_PTR) $<pVoid>3; PopId( $1 ); PushId( $1 ); AliasRemove(); }
           | AliasFunc INASSIGN Expression { --iLine; GenError( _szCErrors, 'E', ERR_INVALID_LVALUE, NULL, NULL ); }
           | AliasFunc PLUSEQ   Expression { --iLine; GenError( _szCErrors, 'E', ERR_INVALID_LVALUE, NULL, NULL ); }
           | AliasFunc MINUSEQ  Expression { --iLine; GenError( _szCErrors, 'E', ERR_INVALID_LVALUE, NULL, NULL ); }
           | AliasFunc MULTEQ   Expression { --iLine; GenError( _szCErrors, 'E', ERR_INVALID_LVALUE, NULL, NULL ); }
           | AliasFunc DIVEQ    Expression { --iLine; GenError( _szCErrors, 'E', ERR_INVALID_LVALUE, NULL, NULL ); }
           | AliasFunc EXPEQ    Expression { --iLine; GenError( _szCErrors, 'E', ERR_INVALID_LVALUE, NULL, NULL ); }
           | AliasFunc MODEQ    Expression { --iLine; GenError( _szCErrors, 'E', ERR_INVALID_LVALUE, NULL, NULL ); }
           ;


Operators  : Expression '='    Expression   { GenPCode1( HB_P_EQUAL ); } /* compare */
           | Expression '+'    Expression   { GenPCode1( HB_P_PLUS ); }
           | Expression '-'    Expression   { GenPCode1( HB_P_MINUS ); }
           | Expression '*'    Expression   { GenPCode1( HB_P_MULT ); }
           | Expression '/'    Expression   { GenPCode1( HB_P_DIVIDE ); }
           | Expression '<'    Expression   { GenPCode1( HB_P_LESS ); }
           | Expression '>'    Expression   { GenPCode1( HB_P_GREATER ); }
           | Expression '$'    Expression   { GenPCode1( HB_P_INSTRING ); }
           | Expression '%'    Expression   { GenPCode1( HB_P_MODULUS ); }
           | Expression LE     Expression   { GenPCode1( HB_P_LESSEQUAL ); }
           | Expression GE     Expression   { GenPCode1( HB_P_GREATEREQUAL ); }
           | Expression AND { if( _bShortCuts ){ Duplicate(); $<iNumber>$ = JumpFalse( 0 ); } }
                       Expression { GenPCode1( HB_P_AND ); if( _bShortCuts ) JumpHere( $<iNumber>3 ); }
           | Expression OR { if( _bShortCuts ){ Duplicate(); $<iNumber>$ = JumpTrue( 0 ); } }
                       Expression { GenPCode1( HB_P_OR ); if( _bShortCuts ) JumpHere( $<iNumber>3 ); }
           | Expression EQ     Expression   { GenPCode1( HB_P_EXACTLYEQUAL ); }
           | Expression NE1    Expression   { GenPCode1( HB_P_NOTEQUAL ); }
           | Expression NE2    Expression   { GenPCode1( HB_P_NOTEQUAL ); }
           | Expression POWER  Expression   { GenPCode1( HB_P_POWER ); }
           | NOT Expression                 { GenPCode1( HB_P_NOT ); }
           | '-' Expression %prec UNARY     { GenPCode1( HB_P_NEGATE ); }
           | '+' Expression %prec UNARY
           | VarAssign                      { _bRValue = FALSE; }
           ;

Logical    : TRUEVALUE                                   { $$ = 1; }
           | FALSEVALUE                                  { $$ = 0; }
           ;

Array      : '{' ElemList '}'                       { GenArray( $2 ); }
           ;

ElemList   : /*empty array*/                        { $$ = 0; }
           | Expression                             { $$ = 1; }
           | ElemList ','                           { if( $$ == 0 ) {
                                                         PushNil();
                                                         PushNil();
                                                         $$ = 2;
                                                       } else {
                                                          PushNil();
                                                          $$++;
                                                       } }
           | ElemList ',' Expression                { if( $$ == 0 )
                                                      {
                                                         PushNil();
                                                         $$ = 2;
                                                       }
                                                       else
                                                          $$++; }
           ;

CodeBlock  : BlockBegin '|' BlockExpList '}'           { CodeBlockEnd(); }
           | BlockBegin BlockList '|' BlockExpList '}' { CodeBlockEnd(); }
           ;

BlockBegin : '{' '|'  { CodeBlockStart(); }
           ;

BlockExpList : Expression                            { $$ = 1; }
           | ','                            { PushNil(); GenPCode1( HB_P_POP ); PushNil(); $$ = 2; }
           | BlockExpList ','                        { GenPCode1( HB_P_POP ); PushNil(); $$++; }
           | BlockExpList ',' { GenPCode1( HB_P_POP ); } Expression  { $$++; }
           ;

BlockList  : IDENTIFIER                            { cVarType = ' '; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_NUMERIC                 { cVarType = 'N'; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_CHARACTER               { cVarType = 'C'; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_DATE                    { cVarType = 'D'; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_LOGICAL                 { cVarType = 'L'; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_ARRAY                   { cVarType = 'A'; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_BLOCK                   { cVarType = 'B'; AddVar( $1 ); $$ = 1; }
           | IDENTIFIER AS_OBJECT                  { cVarType = 'O'; AddVar( $1 ); $$ = 1; }
           | BlockList ',' IDENTIFIER             { AddVar( $3 ); $$++; }
           ;

/* There is a conflict between the use of IF( Expr1, Expr2, Expr3 )
 * and parenthesized expression ( Expr1, Expr2, Expr3 )
 * To solve this conflict we have to split the definitions into more
 * atomic ones.
 *   Also the generation of pcodes have to be delayed and moved to the
 * end of whole parenthesized expression.
 */
PareExpList1: ExpList1 ')'        { ExpListPop( 1 ); }
            ;

PareExpList2: ExpList2 ')'        { ExpListPop( 2 ); }
            ;

PareExpList3: ExpList3 ')'        { /* this needs the special handling if used in inline IF */ }
            ;

PareExpListN: ExpList ')'         { ExpListPop( $1 ); }
           ;

PareExpList : PareExpList1        { }
            | PareExpList2        { }
            | PareExpList3        { ExpListPop( 3 ); }
            | PareExpListN        { }
            ;

ExpList1   : '(' { ExpListPush(); } EmptyExpression
           ;

ExpList2   : ExpList1 ',' { ExpListPush(); } EmptyExpression
           ;

ExpList3   : ExpList2 ',' { ExpListPush(); } EmptyExpression
           ;

ExpList    : ExpList3 { ExpListPush(); } ',' EmptyExpression { $$ = 4; }
           | ExpList  { ExpListPush(); } ',' EmptyExpression { $$++;   }
           ;

VarDefs    : LOCAL { iVarScope = VS_LOCAL; Line(); } VarList Crlf { cVarType = ' '; }
           | STATIC { StaticDefStart() } VarList Crlf { StaticDefEnd( $<iNumber>3 ); }
           | PARAMETERS { if( functions.pLast->bFlags & FUN_USES_LOCAL_PARAMS )
                             GenError( _szCErrors, 'E', ERR_PARAMETERS_NOT_ALLOWED, NULL, NULL );
                          else
                             functions.pLast->wParamNum=0; iVarScope = ( VS_PRIVATE | VS_PARAMETER ); }
                             MemvarList Crlf
           ;

VarList    : VarDef                                  { $$ = 1; }
           | VarList ',' VarDef                      { $$++; }
           ;

VarDef     : IDENTIFIER                                   { cVarType = ' '; AddVar( $1 ); }
           | IDENTIFIER AS_NUMERIC                        { cVarType = 'N'; AddVar( $1 ); }
           | IDENTIFIER AS_CHARACTER                      { cVarType = 'C'; AddVar( $1 ); }
           | IDENTIFIER AS_LOGICAL                        { cVarType = 'L'; AddVar( $1 ); }
           | IDENTIFIER AS_DATE                           { cVarType = 'D'; AddVar( $1 ); }
           | IDENTIFIER AS_ARRAY                          { cVarType = 'A'; AddVar( $1 ); }
           | IDENTIFIER AS_BLOCK                          { cVarType = 'B'; AddVar( $1 ); }
           | IDENTIFIER AS_OBJECT                         { cVarType = 'O'; AddVar( $1 ); }
           | IDENTIFIER INASSIGN Expression               { cVarType = ' '; AddVar( $1 ); PopId( $1 ); }
           | IDENTIFIER AS_NUMERIC   INASSIGN Expression  { cVarType = 'N'; AddVar( $1 ); PopId( $1 ); }
           | IDENTIFIER AS_CHARACTER INASSIGN Expression  { cVarType = 'C'; AddVar( $1 ); PopId( $1 ); }
           | IDENTIFIER AS_LOGICAL   INASSIGN Expression  { cVarType = 'L'; AddVar( $1 ); PopId( $1 ); }
           | IDENTIFIER AS_DATE      INASSIGN Expression  { cVarType = 'D'; AddVar( $1 ); PopId( $1 ); }
           | IDENTIFIER AS_ARRAY     INASSIGN Expression  { cVarType = 'A'; AddVar( $1 ); PopId( $1 ); }
           | IDENTIFIER AS_BLOCK     INASSIGN Expression  { cVarType = 'B'; AddVar( $1 ); PopId( $1 ); }
           | IDENTIFIER AS_OBJECT    INASSIGN Expression  { cVarType = 'O'; AddVar( $1 ); PopId( $1 ); }
           | IDENTIFIER ArrExpList ']'                { cVarType = ' '; AddVar( $1 ); DimArray( $2 ); PopId( $1 ); }
           | IDENTIFIER ArrExpList ']' AS_ARRAY       { cVarType = 'A'; AddVar( $1 ); DimArray( $2 ); PopId( $1 ); }
           ;

ArrExpList : '[' Expression              { $$ = 1; }
           | ArrExpList ',' Expression   { $$++; }
           ;

FieldsDef  : FIELD { iVarScope = VS_FIELD; } FieldList Crlf
           ;

FieldList  : IDENTIFIER                            { cVarType = ' '; $$=FieldsCount(); AddVar( $1 ); }
           | IDENTIFIER AS_NUMERIC                 { cVarType = 'N'; $$=FieldsCount(); AddVar( $1 ); }
           | IDENTIFIER AS_CHARACTER               { cVarType = 'C'; $$=FieldsCount(); AddVar( $1 ); }
           | IDENTIFIER AS_DATE                    { cVarType = 'D'; $$=FieldsCount(); AddVar( $1 ); }
           | IDENTIFIER AS_LOGICAL                 { cVarType = 'L'; $$=FieldsCount(); AddVar( $1 ); }
           | IDENTIFIER AS_ARRAY                   { cVarType = 'A'; $$=FieldsCount(); AddVar( $1 ); }
           | IDENTIFIER AS_BLOCK                   { cVarType = 'B'; $$=FieldsCount(); AddVar( $1 ); }
           | IDENTIFIER AS_OBJECT                  { cVarType = 'O'; $$=FieldsCount(); AddVar( $1 ); }
           | FieldList ',' IDENTIFIER                { AddVar( $3 ); }
           | FieldList IN IDENTIFIER { FieldsSetAlias( $3, $<iNumber>1 ); }
           ;

MemvarDef  : MEMVAR { iVarScope = VS_MEMVAR; } MemvarList Crlf
           ;

MemvarList : IDENTIFIER                            { AddVar( $1 ); }
           | MemvarList ',' IDENTIFIER             { AddVar( $3 ); }
           ;

ExecFlow   : IfEndif
           | DoCase
           | DoWhile
           | ForNext
           | BeginSeq
           ;

IfEndif    : IfBegin EndIf                    { JumpHere( $1 ); }
           | IfBegin IfElse EndIf             { JumpHere( $1 ); }
           | IfBegin IfElseIf EndIf           { JumpHere( $1 ); FixElseIfs( $2 ); }
           | IfBegin IfElseIf IfElse EndIf    { JumpHere( $1 ); FixElseIfs( $2 ); }
           ;

IfBegin    : IF SimpleExpression { ++_wIfCounter; } Crlf { $$ = JumpFalse( 0 ); Line(); }
                IfStats
                { $$ = Jump( 0 ); JumpHere( $<iNumber>5 ); }

           | IF PareExpList1 { ++_wIfCounter; } Crlf { $$ = JumpFalse( 0 ); Line(); }
                IfStats
                { $$ = Jump( 0 ); JumpHere( $<iNumber>5 ); }

           | IF PareExpList2 { ++_wIfCounter; } Crlf { $$ = JumpFalse( 0 ); Line(); }
                IfStats
                { $$ = Jump( 0 ); JumpHere( $<iNumber>5 ); }

           | IF PareExpListN { ++_wIfCounter; } Crlf { $$ = JumpFalse( 0 ); Line(); }
                IfStats
                { $$ = Jump( 0 ); JumpHere( $<iNumber>5 ); }
           ;

IfElse     : ELSE Crlf { Line(); } IfStats
           ;

IfElseIf   : ELSEIF Expression Crlf { $<iNumber>$ = JumpFalse( 0 ); Line(); }
                IfStats { $$ = GenElseIf( 0, Jump( 0 ) ); JumpHere( $<iNumber>4 ); }

           | IfElseIf ELSEIF Expression Crlf { $<iNumber>$ = JumpFalse( 0 ); Line(); }
                IfStats { $$ = GenElseIf( $1, Jump( 0 ) ); JumpHere( $<iNumber>5 ); }
           ;

EndIf      : ENDIF                 { --_wIfCounter; }
           | END                   { --_wIfCounter; }
           ;

IfStats    : /* no statements */
           | Statements
           ;

DoCase     : DoCaseBegin
                Cases
             EndCase                  { FixElseIfs( $2 ); }

           | DoCaseBegin
                Otherwise
             EndCase

           | DoCaseBegin
             EndCase

           | DoCaseBegin
                Cases
                Otherwise
             EndCase                   { FixElseIfs( $2 ); }
           ;

EndCase    : ENDCASE              { --_wCaseCounter; }
           | END                  { --_wCaseCounter; }
           ;

DoCaseBegin : DOCASE { ++_wCaseCounter; } Crlf { Line(); }
           ;

Cases      : CASE Expression Crlf { $<iNumber>$ = JumpFalse( 0 ); Line(); } CaseStmts { $$ = GenElseIf( 0, Jump( 0 ) ); JumpHere( $<iNumber>4 ); Line(); }
           | Cases CASE Expression Crlf { $<iNumber>$ = JumpFalse( 0 ); Line(); } CaseStmts { $$ = GenElseIf( $1, Jump( 0 ) ); JumpHere( $<iNumber>5 ); Line(); }
           ;

Otherwise  : OTHERWISE Crlf { Line(); } CaseStmts
           ;

CaseStmts  : /* no statements */
           | Statements
           ;

DoWhile    : WhileBegin Expression Crlf { $<lNumber>$ = JumpFalse( 0 ); Line(); }
                { Jump( $1 - functions.pLast->lPCodePos ); }
             EndWhile { JumpHere( $<lNumber>4 ); --_wWhileCounter; }

           | WhileBegin Expression Crlf { $<lNumber>$ = JumpFalse( 0 ); Line(); }
                WhileStatements { LoopHere(); Jump( $1 - functions.pLast->lPCodePos ); }
             EndWhile  { JumpHere( $<lNumber>4 ); --_wWhileCounter; LoopEnd(); }
           ;

WhileBegin : WHILE    { $$ = functions.pLast->lPCodePos; ++_wWhileCounter; LoopStart(); }
           ;

WhileStatements : Statement
           | WhileStatements { Line(); } Statement
           ;

EndWhile   : END
           | ENDDO
           ;

ForNext    : FOR IDENTIFIER ForAssign Expression { PopId( $2 ); $<iNumber>$ = functions.pLast->lPCodePos; ++_wForCounter; LoopStart(); }
             TO Expression                       { PushId( $2 ); }
             StepExpr Crlf                       { if( $<lNumber>9 )
                                                      GenPCode1( HB_P_FORTEST );
                                                   else
                                                      GenPCode1( HB_P_LESS );
                                                   $<iNumber>$ = JumpTrue( 0 );
                                                   Line();
                                                 }
             ForStatements                       { LoopHere();
                                                   PushId( $2 );
                                                   if( $<lNumber>9 )
                                                      GenPCode1( HB_P_PLUS );
                                                   else
                                                      Inc();
                                                   PopId( $2 );
                                                   Jump( $<iNumber>5 - functions.pLast->lPCodePos );
                                                   JumpHere( $<iNumber>11 );
                                                   LoopEnd();
                                                   if( $<lNumber>9 )
                                                      GenPCode1( HB_P_POP );
                                                 }
           ;

ForAssign  : '='
           | INASSIGN
           ;

StepExpr   : /* default step expression */       { $<lNumber>$ =0; }
           | STEP Expression                     { $<lNumber>$ =1; }
           ;

ForStatements : ForStat NEXT                     { --_wForCounter; }
           | ForStat NEXT IDENTIFIER             { --_wForCounter; }
           | NEXT                                { --_wForCounter; }
           | NEXT IDENTIFIER                     { --_wForCounter; }
           ;

ForStat    : Statements                          { Line(); }
           ;

BeginSeq   : BEGINSEQ { ++_wSeqCounter; $<lNumber>$ = SequenceBegin(); } Crlf { Line(); }
                SeqStatms
                {
                  /* Set jump address for HB_P_SEQBEGIN opcode - this address
                   * will be used in BREAK code if there is no RECOVER clause
                   */
                  JumpHere( $<lNumber>2 );
                  $<lNumber>$ = SequenceEnd();
                  Line();
                }
                RecoverSeq
                {
                   /* Replace END address with RECOVER address in
                    * HB_P_SEQBEGIN opcode if there is RECOVER clause
                    */
                   if( $<lNumber>7 )
                      JumpThere( $<lNumber>2, $<lNumber>7-( _bLineNumbers ? 3 : 0 ) );
                }
             END
             {
                /* Fix END address
                 * There is no line number after HB_P_SEQEND in case no
                 * RECOVER clause is used
                 */
                JumpThere( $<lNumber>6, functions.pLast->lPCodePos-((_bLineNumbers && !$<lNumber>7)?3:0) );
                if( $<lNumber>7 )   /* only if there is RECOVER clause */
                   LineDebug();
                else
                   --_wSeqCounter;  /* RECOVER is also considered as end of sequence */
                SequenceFinish( $<lNumber>2, $<iNumber>5 );
             }
           ;

SeqStatms  : /* empty */      { $<iNumber>$ = 0; }
           | Statements       { $<iNumber>$ = 1; }
           ;

RecoverSeq : /* no recover */  { $<lNumber>$ = 0; }
           | RecoverEmpty Crlf { $<lNumber>$ = $<lNumber>1; }
           | RecoverEmpty Crlf { $<lNumber>$ = $<lNumber>1; Line(); } Statements
           | RecoverUsing Crlf { $<lNumber>$ = $<lNumber>1; }
           | RecoverUsing Crlf { $<lNumber>$ = $<lNumber>1; Line(); } Statements
           ;

RecoverEmpty : RECOVER
               {
                  $<lNumber>$ = functions.pLast->lPCodePos;
                  --_wSeqCounter;
                  GenPCode1( HB_P_SEQRECOVER );
                  GenPCode1( HB_P_POP );
               }
           ;

RecoverUsing : RECOVER USING IDENTIFIER
               {
                  $<lNumber>$ = functions.pLast->lPCodePos;
                  --_wSeqCounter;
                  GenPCode1( HB_P_SEQRECOVER );
                  PopId( $3 );
               }
           ;

/* NOTE: In Clipper all variables used in DO .. WITH are passed by reference
 * however if they are part of an expression then they are passed by value
 * for example:
 * DO .. WITH ++variable
 * will pass the value of variable not a reference
 */
DoProc     : DO IDENTIFIER { PushSymbol( $2, 1 ); PushNil(); Do( 0 ); }
           | DO IDENTIFIER { PushSymbol( $2, 1 ); PushNil(); _bForceByRefer = TRUE; } WITH DoArgList { Do( $5 ); _bForceByRefer=FALSE; }
           | WHILE { PushSymbol( yy_strdup("WHILE"), 1 ); PushNil(); _bForceByRefer = TRUE; } WITH DoArgList { Do( $4 ); _bForceByRefer=FALSE; }
           ;

DoArgList  : ','                               { PushNil(); PushNil(); $$ = 2; }
           | DoExpression                      { $$ = 1; }
           | DoArgList ','                     { PushNil(); $$++; }
           | DoArgList ',' DoExpression        { $$++; }
           | ',' { PushNil(); } DoExpression   { $$ = 2; }
           ;

DoExpression: Expression         { _bForceByRefer = TRUE; }
           ;

Crlf       : '\n'
           | ';'           { _bDontGenLineNum = TRUE; }
           | '\n' Crlf
           | ';' Crlf      { _bDontGenLineNum = TRUE; }
           ;

%%

void yyerror( char * s )
{
   GenError( _szCErrors, 'E', ERR_YACC, s, NULL );
}

void * GenElseIf( void * pFirst, ULONG ulOffset )
{
   PELSEIF pElseIf = ( PELSEIF ) hb_xgrab( sizeof( _ELSEIF ) ), pLast;

   pElseIf->ulOffset = ulOffset;
   pElseIf->pNext   = 0;

   if( ! pFirst )
      pFirst = pElseIf;
   else
   {
      pLast = ( PELSEIF ) pFirst;
      while( pLast->pNext )
         pLast = pLast->pNext;
      pLast->pNext = pElseIf;
   }
   return pFirst;
}

void GenError( char* _szErrors[], char cPrefix, int iError, char * szError1, char * szError2 )
{
   if( files.pLast != NULL && files.pLast->szFileName != NULL )
      printf( "\r%s(%i) ", files.pLast->szFileName, iLine );

   printf( "Error %c%04i  ", cPrefix, iError );
   printf( _szErrors[ iError - 1 ], szError1, szError2 );
   printf( "\n" );

   exit( EXIT_FAILURE );
}

void GenWarning( char* _szWarnings[], char cPrefix, int iWarning, char * szWarning1, char * szWarning2)
{
   if( _bWarnings && iWarning < WARN_ASSIGN_SUSPECT ) /* TODO: add switch to set level */
   {
      printf( "\r%s(%i) ", files.pLast->szFileName, iLine );
      printf( "Warning %c%04i  ", cPrefix, iWarning );
      printf( _szWarnings[ iWarning - 1 ], szWarning1, szWarning2 );
      printf( "\n" );

      _bAnyWarning = TRUE;
   }
}

void EXTERNAL_LINKAGE close_on_exit( void )
{
   PFILE pFile = files.pLast;

   while( pFile )
   {
/*
      printf( "\nClosing file: %s\n", pFile->szFileName );
*/
      fclose( pFile->handle );
      pFile = ( PFILE ) pFile->pPrev;
   }
}

int harbour_main( int argc, char * argv[] )
{
   int iStatus = 0;
   int iArg;
   BOOL bSkipGen;

   /* Check for the nologo switch /q0 before everything else. */

   for( iArg = 1; iArg < argc; iArg++ )
   {
      if( IS_OPT_SEP( argv[ iArg ][ 0 ] ) &&
          ( argv[ iArg ][ 1 ] == 'q' || argv[ iArg ][ 1 ] == 'Q' ) &&
            argv[ iArg ][ 2 ] == '0' )
      {
         _bLogo = FALSE;
         break;
      }
   }

   if( _bLogo )
   {
      printf( "Harbour Compiler, Build %i%s (%04d.%02d.%02d)\n",
         hb_build, hb_revision, hb_year, hb_month, hb_day );
      printf( "Copyright 1999, http://www.harbour-project.org\n" );
   }

   if( argc > 1 )
   {
      char szFileName[ _POSIX_PATH_MAX ];    /* filename to parse */
      char szPpoName[ _POSIX_PATH_MAX ];
      PHB_FNAME pOutPath = NULL;

      Hbpp_init();  /* Initialization of preprocessor arrays */
      /* Command line options */
      for( iArg = 1; iArg < argc; iArg++ )
      {
         if( IS_OPT_SEP( argv[ iArg ][ 0 ] ) )
         {
            switch( argv[ iArg ][ 1 ] )
            {
               case '1':
                  if( argv[ iArg ][ 2 ] == '0' )
                     _bRestrictSymbolLength = TRUE;
                  break;

               case 'a':
               case 'A':
                  _bAutoMemvarAssume = TRUE;
                  break;

               case 'b':
               case 'B':
                  _bDebugInfo = TRUE;
                  _bLineNumbers = TRUE;
                  break;

               case 'd':
               case 'D':   /* defines a Lex #define from the command line */
                  {
                     unsigned int i = 0;
                     char * szDefText = yy_strdup( argv[ iArg ] + 2 );
                     while( i < strlen( szDefText ) && szDefText[ i ] != '=' )
                        i++;
                     if( szDefText[ i ] != '=' )
                        AddDefine( szDefText, 0 );
                     else
                     {
                        szDefText[ i ] = '\0';
                        AddDefine( szDefText, szDefText + i + 1 );
                     }
                     free( szDefText );
                  }
                  break;

               case 'e':
               case 'E':

                  if( argv[ iArg ][ 2 ] == 's' ||
                      argv[ iArg ][ 2 ] == 'S' )
                  {
                     switch( argv[ iArg ][ 3 ] )
                     {
                        case '\0':
                        case '0':
                           _iExitLevel = HB_EXITLEVEL_DEFAULT;
                           break;

                        case '1':
                           _iExitLevel = HB_EXITLEVEL_SETEXIT;
                           break;

                        case '2':
                           _iExitLevel = HB_EXITLEVEL_DELTARGET;
                           break;

                        default:
                           GenError( _szCErrors, 'E', ERR_BADOPTION, &argv[ iArg ][ 0 ], NULL );
                     }
                  }
                  else
                     GenError( _szCErrors, 'E', ERR_BADOPTION, &argv[ iArg ][ 0 ], NULL );

                  break;

#ifdef HARBOUR_OBJ_GENERATION
               case 'f':
               case 'F':
                  {
                     char * szUpper = yy_strupr( yy_strdup( &argv[ iArg ][ 2 ] ) );
                     if( ! strcmp( szUpper, "OBJ32" ) )
                        _bObj32 = TRUE;
                     free( szUpper );
                  }
                  break;
#endif
               case 'g':
               case 'G':
                  switch( argv[ iArg ][ 2 ] )
                  {
                     case 'c':
                     case 'C':
                        _iLanguage = LANG_C;
                        break;

                     case 'j':
                     case 'J':
                        _iLanguage = LANG_JAVA;
                        break;

                     case 'p':
                     case 'P':
                        _iLanguage = LANG_PASCAL;
                        break;

                     case 'r':
                     case 'R':
                        _iLanguage = LANG_RESOURCES;
                        break;

                     case 'h':
                     case 'H':
                        _iLanguage = LANG_PORT_OBJ;
                        break;

                     default:
                        printf( "\nUnsupported output language option\n" );
                        exit( EXIT_FAILURE );
                  }
                  break;

               case 'i':
               case 'I':
                  AddSearchPath( argv[ iArg ] + 2, &_pIncludePath );
                  break;

               case 'l':
               case 'L':
                  _bLineNumbers = FALSE;
                  break;

               case 'm':
               case 'M':
                  /* TODO: Implement this switch */
                  printf( "Not yet supported command line option: %s\n", &argv[ iArg ][ 0 ] );
                  break;

               case 'n':
               case 'N':
                  _bStartProc = FALSE;
                  break;

               case 'o':
               case 'O':
                  pOutPath = hb_fsFNameSplit( argv[ iArg ] + 2 );
                  break;

               /* Added for preprocessor needs */
               case 'p':
               case 'P':
                  _bPPO = TRUE;
                  break;

               case 'q':
               case 'Q':
                  _bQuiet = TRUE;
                  break;

               case 'r':
               case 'R':
                  /* TODO: Implement this switch */
                  printf( "Not yet supported command line option: %s\n", &argv[ iArg ][ 0 ] );
                  break;

               case 's':
               case 'S':
                  _bSyntaxCheckOnly = TRUE;
                  break;

               case 't':
               case 'T':
                  /* TODO: Implement this switch */
                  printf( "Not yet supported command line option: %s\n", &argv[ iArg ][ 0 ] );
                  break;

               case 'u':
               case 'U':
                  /* TODO: Implement this switch */
                  printf( "Not yet supported command line option: %s\n", &argv[ iArg ][ 0 ] );
                  break;

               case 'v':
               case 'V':
                  _bForceMemvars = TRUE;
                  break;

               case 'w':
               case 'W':
                  _bWarnings = TRUE;
                  break;

               case 'x':
               case 'X':
                  {
                     if( strlen( argv[ iArg ] + 2 ) == 0 )
                        sprintf( _szPrefix, "%08lX_", PackDateTime() );
                     else
                     {
                        strncpy( _szPrefix, argv[ iArg ] + 2, 16 );
                        _szPrefix[ 16 ] = '\0';
                        strcat( _szPrefix, "_" );
                     }
                  }
                  break;

#ifdef YYDEBUG
               case 'y':
               case 'Y':
                  yydebug = TRUE;
                  break;
#endif

               case 'z':
               case 'Z':
                  _bShortCuts = FALSE;
                  break;

               default:
                  GenError( _szCErrors, 'E', ERR_BADOPTION, &argv[ iArg ][ 0 ], NULL );
                  break;
            }
         }
         else if( argv[ iArg ][ 0 ] == '@' )
            /* TODO: Implement this switch */
            printf( "Not yet supported command line option: %s\n", &argv[ iArg ][ 0 ] );
         else
            _pFileName = hb_fsFNameSplit( argv[ iArg ] );
      }

      if( _pFileName )
      {
         if( !_pFileName->szExtension )
            _pFileName->szExtension = ".prg";
         hb_fsFNameMerge( szFileName, _pFileName );
         if( _bPPO )
         {
            _pFileName->szExtension = ".ppo";
            hb_fsFNameMerge( szPpoName, _pFileName );
            yyppo = fopen( szPpoName, "w" );
            if( ! yyppo )
            {
               GenError( _szCErrors, 'E', ERR_CREATE_PPO, szPpoName, NULL );
               return iStatus;
            }
         }
      }
      else
      {
         PrintUsage( argv[ 0 ] );
         return iStatus;
      }

      files.iFiles     = 0;        /* initialize support variables */
      files.pLast      = NULL;
      functions.iCount = 0;
      functions.pFirst = NULL;
      functions.pLast  = NULL;
      funcalls.iCount  = 0;
      funcalls.pFirst  = NULL;
      funcalls.pLast   = NULL;
      symbols.iCount   = 0;
      symbols.pFirst   = NULL;
      symbols.pLast    = NULL;

      _pInitFunc = NULL;
      _bAnyWarning = FALSE;

      atexit( close_on_exit );

      if( Include( szFileName, NULL ) )
      {
         char * szInclude = getenv( "INCLUDE" );

         if( szInclude )
         {
            char * pPath;
            char * pDelim;

            pPath = szInclude = yy_strdup( szInclude );
            while( ( pDelim = strchr( pPath, OS_PATH_LIST_SEPARATOR ) ) != NULL )
            {
               *pDelim = '\0';
               AddSearchPath( pPath, &_pIncludePath );
               pPath = pDelim + 1;
            }
            AddSearchPath( pPath, &_pIncludePath );
         }

         /* Generate the starting procedure frame
          */
         if( _bStartProc )
            FunDef( yy_strupr( yy_strdup( _pFileName->szName ) ), FS_PUBLIC, FUN_PROCEDURE );
         else
             /* Don't pass the name of module if the code for starting procedure
             * will be not generated. The name cannot be placed as first symbol
             * because this symbol can be used as function call or memvar's name.
             */
            FunDef( yy_strupr( yy_strdup( "" ) ), FS_PUBLIC, FUN_PROCEDURE );

         yyparse();

         GenExterns();       /* generates EXTERN symbols names */
         fclose( yyin );
         files.pLast = NULL;

         bSkipGen = FALSE;

         if( _bAnyWarning )
         {
            if( _iExitLevel == HB_EXITLEVEL_SETEXIT )
               iStatus = 1;
            if( _iExitLevel == HB_EXITLEVEL_DELTARGET )
            {
               iStatus = 1;
               bSkipGen = TRUE;
               printf( "\nNo code generated\n" );
            }
         }

#ifdef HARBOUR_OBJ_GENERATION
         if( ! _bSyntaxCheckOnly && ! bSkipGen && ! _bObj32 )
#else
         if( ! _bSyntaxCheckOnly && ! bSkipGen )
#endif
         {
            if( _pInitFunc )
            {
               PCOMSYMBOL pSym;

               /* Fix the number of static variables */
               _pInitFunc->pCode[ 1 ] = LOBYTE( _iStatics );
               _pInitFunc->pCode[ 2 ] = HIBYTE( _iStatics );
               _pInitFunc->iStaticsBase = _iStatics;

               pSym = AddSymbol( _pInitFunc->szName, NULL );
               pSym->cScope |= _pInitFunc->cScope;
               functions.pLast->pNext = _pInitFunc;
               ++functions.iCount;
            }

            _pFileName->szPath = NULL;
            _pFileName->szExtension = NULL;

            /* we create a the output file */
            if( pOutPath )
            {
               if( pOutPath->szPath )
                  _pFileName->szPath = pOutPath->szPath;
               if( pOutPath->szName )
               {
                  _pFileName->szName = pOutPath->szName;
                  if( pOutPath->szExtension )
                     _pFileName->szExtension = pOutPath->szExtension;
               }
            }

            switch( _iLanguage )
            {
               case LANG_C:
                  if( ! _pFileName->szExtension )
                     _pFileName->szExtension =".c";
                  hb_fsFNameMerge( szFileName, _pFileName );
                  GenCCode( szFileName, _pFileName->szName );
                  break;

               case LANG_JAVA:
                  if( ! _pFileName->szExtension )
                     _pFileName->szExtension =".java";
                  hb_fsFNameMerge( szFileName, _pFileName );
                  GenJava( szFileName, _pFileName->szName );
                  break;

               case LANG_PASCAL:
                  if( ! _pFileName->szExtension )
                     _pFileName->szExtension =".pas";
                  hb_fsFNameMerge( szFileName, _pFileName );
                  GenPascal( szFileName, _pFileName->szName );
                  break;

               case LANG_RESOURCES:
                  if( ! _pFileName->szExtension )
                     _pFileName->szExtension =".rc";
                  hb_fsFNameMerge( szFileName, _pFileName );
                  GenRC( szFileName, _pFileName->szName );
                  break;

               case LANG_PORT_OBJ:
                  if( ! _pFileName->szExtension )
                     _pFileName->szExtension =".hrb";
                  hb_fsFNameMerge( szFileName, _pFileName );
                  GenPortObj( szFileName, _pFileName->szName );
                  break;
            }
         }
#ifdef HARBOUR_OBJ_GENERATION
         if( _bObj32 )
         {
            if( ! _pFileName->szExtension )
               _pFileName->szExtension = ".obj";
            hb_fsFNameMerge( szFileName, _pFileName );
            GenObj32( szFileName, _pFileName->szName );
         }
#endif
         if( _bPPO )
            fclose( yyppo );
      }
      else
      {
         printf( "Can't open input file: %s\n", szFileName );
         iStatus = 1;
      }
      hb_xfree( ( void * ) _pFileName );
      if( pOutPath ) hb_xfree( pOutPath );
   }
   else
      PrintUsage( argv[ 0 ] );

   return iStatus;
}

/*
 * Prints available options
*/
void PrintUsage( char * szSelf )
{
   printf( "Syntax: %s <file.prg> [options]\n"
           "\nOptions: \n"
           "\t/a\t\tautomatic memvar declaration\n"
           "\t/b\t\tdebug info\n"
           "\t/d<id>[=<val>]\t#define <id>\n"
           "\t/es[<level>]\tset exit severity\n"
#ifdef HARBOUR_OBJ_GENERATION
           "\t/f\t\tgenerated object file\n"
           "\t\t\t /fobj32 --> Windows/Dos 32 bits OBJ\n"
#endif
           "\t/g\t\tgenerated output language\n"
           "\t\t\t /gc (C default) --> <file.c>\n"
           "\t\t\t /gh (HRB file)  --> <file.hrb>\n"
           "\t\t\t /gj (Java)      --> <file.java>\n"
           "\t\t\t /gp (Pascal)    --> <file.pas>\n"
           "\t\t\t /gr (Resources) --> <file.rc>\n"
           "\t/i<path>\tadd #include file search path\n"
           "\t/l\t\tsuppress line number information\n"
/* TODO:   "\t/m\t\tcompile module only\n" */
           "\t/n\t\tno implicit starting procedure\n"
           "\t/o<path>\tobject file drive and/or path\n"
           "\t/p\t\tgenerate pre-processed output (.ppo) file\n"
           "\t/q\t\tquiet\n"
/* TODO:   "\t/r[<lib>]\trequest linker to search <lib> (or none)\n" */
           "\t/s\t\tsyntax check only\n"
/* TODO:   "\t/t<path>\tpath for temp file creation\n" */
/* TODO:   "\t/u[<file>]\tuse command def set in <file> (or none)\n" */
           "\t/v\t\tvariables are assumed M->\n"
           "\t/w\t\tenable warnings\n"
           "\t/x[<prefix>]\tset symbol init function name prefix\n"
#ifdef YYDEBUG
           "\t/y\t\ttrace lex & yacc activity\n"
#endif
           "\t/z\t\tsuppress shortcutting (.and. & .or.)\n"
           "\t/10\t\trestrict symbol length to 10 characters\n"
/* TODO:   "\t @<file>\tcompile list of modules in <file>\n" */
           , szSelf );
}

/*
 * Function that adds specified path to the list of pathnames to search
 */
void AddSearchPath( char * szPath, PATHNAMES * * pSearchList )
{
   PATHNAMES * pPath = *pSearchList;

   if( pPath )
   {
      while( pPath->pNext )
      pPath = pPath->pNext;
      pPath->pNext = ( PATHNAMES * ) hb_xgrab( sizeof( PATHNAMES ) );
      pPath = pPath->pNext;
   }
   else
   {
      *pSearchList = pPath = ( PATHNAMES * ) hb_xgrab( sizeof( PATHNAMES ) );
   }
   pPath->pNext  = NULL;
   pPath->szPath = szPath;
}


/*
 * This function adds the name of called function into the list
 * as they have to be placed on the symbol table later than the first
 * public symbol
 */
PFUNCTION AddFunCall( char * szFunctionName )
{
   PFUNCTION pFunc = FunctionNew( szFunctionName, 0 );

   if( ! funcalls.iCount )
   {
      funcalls.pFirst = pFunc;
      funcalls.pLast  = pFunc;
   }
   else
   {
      ( ( PFUNCTION ) funcalls.pLast )->pNext = pFunc;
      funcalls.pLast = pFunc;
   }
   funcalls.iCount++;

   return pFunc;
}

/*
 * This function adds the name of external symbol into the list of externals
 * as they have to be placed on the symbol table later than the first
 * public symbol
 */
void AddExtern( char * szExternName ) /* defines a new extern name */
{
   PEXTERN pExtern = ( PEXTERN ) hb_xgrab( sizeof( _EXTERN ) ), pLast;

   pExtern->szName = szExternName;
   pExtern->pNext  = NULL;

   if( pExterns == NULL )
      pExterns = pExtern;
   else
   {
      pLast = pExterns;
      while( pLast->pNext )
         pLast = pLast->pNext;
      pLast->pNext = pExtern;
   }
}

void AddVar( char * szVarName )
{
   PVAR pVar, pLastVar;
   PFUNCTION pFunc = functions.pLast;

   if( ! _bStartProc && functions.iCount <= 1 && iVarScope == VS_LOCAL )
   {
      /* Variable declaration is outside of function/procedure body.
         In this case only STATIC and PARAMETERS variables are allowed. */
      --iLine;
      GenError( _szCErrors, 'E', ERR_OUTSIDE, NULL, NULL );
   }

   /* check if we are declaring local/static variable after some
    * executable statements
    * Note: FIELD and MEMVAR are executable statements
    */
   if( ( functions.pLast->bFlags & FUN_STATEMENTS ) && !( iVarScope == VS_FIELD || ( iVarScope & VS_MEMVAR ) ) )
   {
      --iLine;
      GenError( _szCErrors, 'E', ERR_FOLLOWS_EXEC, ( iVarScope == VS_LOCAL ? "LOCAL" : "STATIC" ), NULL );
   }

   /* When static variable is added then functions.pLast points to function
    * that will initialise variables. The function where variable is being
    * defined is stored in pOwner member.
    */
   if( iVarScope == VS_STATIC )
   {
      pFunc = pFunc->pOwner;
      /* Check if an illegal action was invoked during a static variable
       * value initialization
       */
      if( _pInitFunc->bFlags & FUN_ILLEGAL_INIT )
         GenError( _szCErrors, 'E', ERR_ILLEGAL_INIT, szVarName, pFunc->szName );
   }

   /* Check if a declaration of duplicated variable name is requested */
   if( pFunc->szName )
   {
      /* variable defined in a function/procedure */
      CheckDuplVars( pFunc->pFields, szVarName, iVarScope );
      CheckDuplVars( pFunc->pStatics, szVarName, iVarScope );
      if( !( iVarScope == VS_PRIVATE || iVarScope == VS_PUBLIC ) )
         CheckDuplVars( pFunc->pMemvars, szVarName, iVarScope );
   }
   else
      /* variable defined in a codeblock */
      iVarScope = VS_PARAMETER;
   CheckDuplVars( pFunc->pLocals, szVarName, iVarScope );

   pVar = ( PVAR ) hb_xgrab( sizeof( VAR ) );
   pVar->szName = szVarName;
   pVar->szAlias = NULL;
   pVar->cType = cVarType;
   pVar->iUsed = 0;
   pVar->pNext = NULL;

   if( iVarScope & VS_MEMVAR )
   {
      PCOMSYMBOL pSym;
      WORD wPos;

      if( _bAutoMemvarAssume || iVarScope == VS_MEMVAR )
      {
         /** add this variable to the list of MEMVAR variables
          */
         if( ! pFunc->pMemvars )
            pFunc->pMemvars = pVar;
         else
         {
            pLastVar = pFunc->pMemvars;
            while( pLastVar->pNext )
               pLastVar = pLastVar->pNext;
            pLastVar->pNext = pVar;
         }
      }

      switch( iVarScope )
      {
         case VS_MEMVAR:
            /* variable declared in MEMVAR statement */
            break;
         case ( VS_PARAMETER | VS_PRIVATE ):
            {
               BOOL bNewParameter = FALSE;

               if( ++functions.pLast->wParamNum > functions.pLast->wParamCount )
               {
                  functions.pLast->wParamCount = functions.pLast->wParamNum;
                  bNewParameter = TRUE;
               }

               pSym = GetSymbol( szVarName, &wPos ); /* check if symbol exists already */
               if( ! pSym )
                  pSym = AddSymbol( yy_strdup( szVarName ), &wPos );
               pSym->cScope |= VS_MEMVAR;
               GenPCode3( HB_P_PARAMETER, LOBYTE( wPos ), HIBYTE( wPos ) );
               GenPCode1( LOBYTE( functions.pLast->wParamNum ) );

               /* Add this variable to the local variables list - this will
                * allow to use the correct positions for real local variables.
                * The name of variable have to be hidden because we should
                * not find this name on the local variables list.
                * We have to use the new structure because it is used in
                * memvars list already.
                */
               if( bNewParameter )
               {
                  pVar = ( PVAR ) hb_xgrab( sizeof( VAR ) );
                  pVar->szName = yy_strdup( szVarName );
                  pVar->szAlias = NULL;
                  pVar->cType = cVarType;
                  pVar->iUsed = 0;
                  pVar->pNext = NULL;
                  pVar->szName[ 0 ] ='!';
                  if( ! pFunc->pLocals )
                     pFunc->pLocals = pVar;
                  else
                  {
                     pLastVar = pFunc->pLocals;
                     while( pLastVar->pNext )
                        pLastVar = pLastVar->pNext;
                     pLastVar->pNext = pVar;
                  }
               }
            }
            break;
         case VS_PRIVATE:
            {
               PushSymbol( yy_strdup( "__MVPRIVATE" ), 1);
               PushNil();
               PushSymbol( yy_strdup( szVarName ), 0 );
               Do( 1 );
               pSym = GetSymbol( szVarName, NULL );
               pSym->cScope |= VS_MEMVAR;
            }
            break;
         case VS_PUBLIC:
            {
               PushSymbol( yy_strdup( "__MVPUBLIC" ), 1);
               PushNil();
               PushSymbol( yy_strdup( szVarName ), 0 );
               Do( 1 );
               pSym = GetSymbol( szVarName, NULL );
               pSym->cScope |= VS_MEMVAR;
            }
            break;
      }
   }
   else
   {
      switch( iVarScope )
      {
         case VS_LOCAL:
         case VS_PARAMETER:
            {
               WORD wLocal = 1;

               if( ! pFunc->pLocals )
                  pFunc->pLocals = pVar;
               else
               {
                  pLastVar = pFunc->pLocals;
                  while( pLastVar->pNext )
                  {
                     pLastVar = pLastVar->pNext;
                     wLocal++;
                  }
                  pLastVar->pNext = pVar;
               }
               if( iVarScope == VS_PARAMETER )
               {
                  ++functions.pLast->wParamCount;
                  functions.pLast->bFlags |= FUN_USES_LOCAL_PARAMS;
               }
               if( _bDebugInfo )
               {
                  GenPCode3( HB_P_LOCALNAME, LOBYTE( wLocal ), HIBYTE( wLocal ) );
                  GenPCodeN( ( BYTE * )szVarName, strlen( szVarName ) );
                  GenPCode1( 0 );
               }
            }
            break;

         case VS_STATIC:
            if( ! pFunc->pStatics )
               pFunc->pStatics = pVar;
            else
            {
               pLastVar = pFunc->pStatics;
               while( pLastVar->pNext )
                  pLastVar = pLastVar->pNext;
               pLastVar->pNext = pVar;
            }
            break;

         case VS_FIELD:
            if( ! pFunc->pFields )
               pFunc->pFields = pVar;
            else
            {
               pLastVar = pFunc->pFields;
               while( pLastVar->pNext )
                  pLastVar = pLastVar->pNext;
               pLastVar->pNext = pVar;
            }
            break;
      }

   }
}

PCOMSYMBOL AddSymbol( char * szSymbolName, WORD * pwPos )
{
   PCOMSYMBOL pSym = ( PCOMSYMBOL ) hb_xgrab( sizeof( COMSYMBOL ) );

   pSym->szName = szSymbolName;
   pSym->cScope = 0;
   pSym->cType = cVarType;
   pSym->pNext = NULL;

   if( ! symbols.iCount )
   {
      symbols.pFirst = pSym;
      symbols.pLast  = pSym;
   }
   else
   {
      ( ( PCOMSYMBOL ) symbols.pLast )->pNext = pSym;
      symbols.pLast = pSym;
   }
   symbols.iCount++;

   if( pwPos )
      *pwPos = symbols.iCount;

   /*if( cVarType != ' ') printf("\nDeclared %s as type %c at symbol %i\n", szSymbolName, cVarType, symbols.iCount );*/
   return pSym;
}

/* Adds new alias to the alias stack
 */
void AliasAdd( ALIASID_PTR pAlias )
{
   pAlias->pPrev = pAliasId;
   pAliasId = pAlias;
}

/* Restores previously selected alias
 */
void AliasRemove( void )
{
   ALIASID_PTR pAlias = pAliasId;

   pAliasId = pAliasId->pPrev;
   hb_xfree( pAlias );
}

/* Adds an integer workarea number into alias stack
 */
void AliasAddInt( int iWorkarea )
{
   ALIASID_PTR pAlias = ( ALIASID_PTR ) hb_xgrab( sizeof( ALIASID ) );

   pAlias->type = ALIAS_NUMBER;
   pAlias->alias.iAlias = iWorkarea;
   AliasAdd( pAlias );
}

/* Adds an expression into alias stack
 */
void AliasAddExp( void )
{
   ALIASID_PTR pAlias = ( ALIASID_PTR ) hb_xgrab( sizeof( ALIASID ) );

   pAlias->type = ALIAS_EVAL;
   AliasAdd( pAlias );
}

/* Adds an alias name into alias stack
 */
void AliasAddStr( char * szAlias )
{
   ALIASID_PTR pAlias = ( ALIASID_PTR ) hb_xgrab( sizeof( ALIASID ) );

   pAlias->type = ALIAS_NAME;
   pAlias->alias.szAlias = szAlias;
   AliasAdd( pAlias );
}

/* Generates pcodes to store the current workarea number
 */
void AliasPush( void )
{
   GenPCode1( HB_P_PUSHALIAS );
}

/* Generates pcodes to select the workarea number using current value
 * from the eval stack
 */
void AliasPop( void )
{
   GenPCode1( HB_P_POPALIAS );
}

/* Generates pcodes to swap two last items from the eval stack.
 * Last item (after swaping) is next popped as current workarea
 */
void AliasSwap( void )
{
   GenPCode1( HB_P_SWAPALIAS );
}

int Include( char * szFileName, PATHNAMES * pSearch )
{
   PFILE pFile;

   yyin = fopen( szFileName, "r" );
   if( ! yyin )
   {
      if( pSearch )
      {
         PHB_FNAME pFileName = hb_fsFNameSplit( szFileName );
         char szFName[ _POSIX_PATH_MAX ];    /* filename to parse */

         pFileName->szName = szFileName;
         pFileName->szExtension = NULL;
         while( pSearch && !yyin )
         {
            pFileName->szPath = pSearch->szPath;
            hb_fsFNameMerge( szFName, pFileName );
            yyin = fopen( szFName, "r" );
            if( ! yyin )
            {
               pSearch = pSearch->pNext;
               if( ! pSearch )
                  return 0;
            }
         }
         hb_xfree( ( void * ) pFileName );
      }
      else
         return 0;
   }

   if( ! _bQuiet )
      printf( "\nCompiling \'%s\'\n", szFileName );

   pFile = ( PFILE ) hb_xgrab( sizeof( _FILE ) );
   pFile->handle = yyin;
   pFile->szFileName = szFileName;
   pFile->pPrev = NULL;

   if( ! files.iFiles )
      files.pLast = pFile;
   else
   {
      files.pLast->iLine = iLine;
      iLine = 1;
      pFile->pPrev = files.pLast;
      files.pLast  = pFile;
   }
#ifdef __cplusplus
   yy_switch_to_buffer( ( YY_BUFFER_STATE ) ( pFile->pBuffer = yy_create_buffer( yyin, 8192 * 2 ) ) );
#else
   yy_switch_to_buffer( pFile->pBuffer = yy_create_buffer( yyin, 8192 * 2 ) );
#endif
   files.iFiles++;
   return 1;
}

int yywrap( void )   /* handles the EOF of the currently processed file */
{
   void * pLast;

   if( files.iFiles == 1 )
      return 1;      /* we have reached the main EOF */
   else
   {
      pLast = files.pLast;
      fclose( files.pLast->handle );
      files.pLast = ( PFILE ) ( ( PFILE ) files.pLast )->pPrev;
      iLine = files.pLast->iLine;
      if( ! _bQuiet )
         printf( "\nCompiling %s\n", files.pLast->szFileName );
#ifdef __cplusplus
      yy_delete_buffer( ( YY_BUFFER_STATE ) ( ( PFILE ) pLast )->pBuffer );
#else
      yy_delete_buffer( ( ( PFILE ) pLast )->pBuffer );
#endif
      free( pLast );
      files.iFiles--;
      yyin = files.pLast->handle;
#ifdef __cplusplus
      yy_switch_to_buffer( ( YY_BUFFER_STATE ) files.pLast->pBuffer );
#else
      yy_switch_to_buffer( files.pLast->pBuffer );
#endif
      return 0;      /* we close the currently include file and continue */
   }
}

void Duplicate( void )
{
   GenPCode1( HB_P_DUPLICATE );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pNewStackType;

      pNewStackType = ( STACK_VAL_TYPE * )hb_xgrab( sizeof( STACK_VAL_TYPE ) );
      pNewStackType->cType = pStackValType->cType;
      pNewStackType->pPrev = pStackValType;

      pStackValType = pNewStackType;
      /*debug_msg( "\n* *Duplicate()\n ", NULL );*/
   }
}

void DupPCode( ULONG ulStart ) /* duplicates the current generated pcode from an offset */
{
   ULONG w, wEnd = functions.pLast->lPCodePos - ulStart;

   for( w = 0; w < wEnd; w++ )
      GenPCode1( functions.pLast->pCode[ ulStart + w ] );
}

/*
 * Starts a new expression in the parenthesized epressions list
 */
void ExpListPush( void )
{
   EXPLIST_PTR pExp = ( EXPLIST_PTR ) hb_xgrab( sizeof( EXPLIST ) );

   pExp->pNext = pExp->pPrev = NULL;

   /* Store the previous state on the stack */
   if( _pExpList )
   {
      _pExpList->pNext = pExp;
      pExp->pPrev = _pExpList;
      /* save currently used pcode buffer */
      _pExpList->exprSize = functions.pLast->lPCodePos;
   }
   _pExpList   = pExp;

   /* store current pcode buffer */
   pExp->prevPCode = functions.pLast->pCode;
   pExp->prevSize  = functions.pLast->lPCodeSize;
   pExp->prevPos   = functions.pLast->lPCodePos;

   /* and create the new one */
   functions.pLast->pCode = ( BYTE * ) hb_xgrab( PCODE_CHUNK );
   functions.pLast->lPCodeSize = PCODE_CHUNK;
   functions.pLast->lPCodePos  = 0;

   pExp->exprPCode = functions.pLast->pCode;
}

/*
 * Pops specified number of expressions from the stack
 */
void ExpListPop( int iExpCount )
{
   EXPLIST_PTR pExp, pDel;

   /* save currently used pcode buffer */
   _pExpList->exprSize  = functions.pLast->lPCodePos;
   _pExpList->exprPCode = functions.pLast->pCode;

   /* find the first expression in the list */
   while( --iExpCount )
      _pExpList = _pExpList->pPrev;

   /* return to the original pcode buffer */
   functions.pLast->pCode      = _pExpList->prevPCode;
   functions.pLast->lPCodeSize = _pExpList->prevSize;
   functions.pLast->lPCodePos  = _pExpList->prevPos;

   pExp = _pExpList;
   if( _pExpList->pPrev )
   {
      _pExpList = _pExpList->pPrev;
      _pExpList->pNext = NULL;
   }
   else
      _pExpList = NULL;

   while( pExp )
   {
      if( pExp->exprSize )
      {
         GenPCodeN( pExp->exprPCode, pExp->exprSize );
         if( pExp->pNext )
            GenPCode1( HB_P_POP );
      }
      else
      {
         /* exprN, , exprN1
          * in this context empty expression is not allowed
          *
          * NOTE:
          * We don't have to generate this error - it is safe to continue
          * pcode generation - in this case an empty expression will not
          * generate any opcode
          */
         GenError( _szCErrors, 'E', ERR_SYNTAX, ")", NULL );
      }

      hb_xfree( pExp->exprPCode );

      pDel = pExp;
      pExp = pExp->pNext;
      hb_xfree( pDel );
   }
}


/*
 * Function generates passed pcode for passed database field
 */
void FieldPCode( BYTE bPCode, char * szVarName )
{
   WORD wVar;
   PCOMSYMBOL pVar;

   pVar = GetSymbol( szVarName, &wVar );
   if( ! pVar )
      pVar = AddSymbol( szVarName, &wVar );
   pVar->cScope |= VS_MEMVAR;
   GenPCode3( bPCode, LOBYTE( wVar ), HIBYTE( wVar ) );
}

/*
 * This function creates and initialises the _FUNC structure
 */
PFUNCTION FunctionNew( char * szName, SYMBOLSCOPE cScope )
{
   PFUNCTION pFunc;

   pFunc = ( PFUNCTION ) hb_xgrab( sizeof( _FUNC ) );
   pFunc->szName       = szName;
   pFunc->cScope       = cScope;
   pFunc->pLocals      = NULL;
   pFunc->pStatics     = NULL;
   pFunc->pFields      = NULL;
   pFunc->pMemvars     = NULL;
   pFunc->pCode        = NULL;
   pFunc->lPCodeSize   = 0;
   pFunc->lPCodePos    = 0;
   pFunc->pNext        = NULL;
   pFunc->wParamCount  = 0;
   pFunc->wParamNum    = 0;
   pFunc->iStaticsBase = _iStatics;
   pFunc->pOwner       = NULL;
   pFunc->bFlags       = 0;

   return pFunc;
}

/*
 * Stores a Clipper defined function/procedure
 * szFunName - name of a function
 * cScope    - scope of a function
 * iType     - FUN_PROCEDURE if a procedure or 0
 */
void FunDef( char * szFunName, SYMBOLSCOPE cScope, int iType )
{
   PCOMSYMBOL   pSym;
   PFUNCTION pFunc;
   char * szFunction;

   pFunc = GetFunction( szFunName );
   if( pFunc )
   {
      /* The name of a function/procedure is already defined */
      if( ( pFunc != functions.pFirst ) || _bStartProc )
         /* it is not a starting procedure that was automatically created */
         GenError( _szCErrors, 'E', ERR_FUNC_DUPL, szFunName, NULL );
   }

   szFunction = RESERVED_FUNC( szFunName );
   if( szFunction && !( functions.iCount==0 && !_bStartProc ) )
   {
      /* We are ignoring it when it is the name of PRG file and we are
       * not creating implicit starting procedure
       */
      GenError( _szCErrors, 'E', ERR_FUNC_RESERVED, szFunction, szFunName );
   }

   iFunctions++;

   FixReturns();    /* fix all previous function returns offsets */

   pSym = GetSymbol( szFunName, NULL );
   if( ! pSym )
      /* there is not a symbol on the symbol table for this function name */
      pSym = AddSymbol( szFunName, NULL );

   if( cScope != FS_PUBLIC )
/*    pSym->cScope = FS_PUBLIC; */
/* else */
      pSym->cScope |= cScope; /* we may have a non public function and a object message */

   pFunc = FunctionNew( szFunName, cScope );
   pFunc->bFlags |= iType;

   if( functions.iCount == 0 )
   {
      functions.pFirst = pFunc;
      functions.pLast  = pFunc;
   }
   else
   {
      functions.pLast->pNext = pFunc;
      functions.pLast = pFunc;
   }
   functions.iCount++;

   _ulLastLinePos = 0;   /* optimization of line numbers opcode generation */

   GenPCode3( HB_P_FRAME, 0, 0 );   /* frame for locals and parameters */
   GenPCode3( HB_P_SFRAME, 0, 0 );     /* frame for statics variables */

   if( _bDebugInfo )
   {
      GenPCode1( HB_P_MODULENAME );
      GenPCodeN( ( BYTE * )files.pLast->szFileName, strlen( files.pLast->szFileName ) );
      GenPCode1( ':' );
      GenPCodeN( ( BYTE * )szFunName, strlen( szFunName ) );
      GenPCode1( 0 );
   }
}

PFUNCTION KillFunction( PFUNCTION pFunc )
{
   PFUNCTION pNext = pFunc->pNext;
   PVAR pVar;

   while( pFunc->pLocals )
   {
      pVar = pFunc->pLocals;
      pFunc->pLocals = pVar->pNext;

      hb_xfree( ( void * ) pVar->szName );
      hb_xfree( ( void * ) pVar );
   }

   while( pFunc->pStatics )
   {
      pVar = pFunc->pStatics;
      pFunc->pStatics = pVar->pNext;

      hb_xfree( ( void * ) pVar->szName );
      hb_xfree( ( void * ) pVar );
   }

   while( pFunc->pFields )
   {
      pVar = pFunc->pFields;
      pFunc->pFields = pVar->pNext;

      hb_xfree( ( void * ) pVar->szName );
      if( pVar->szAlias )
      {
         hb_xfree( ( void * ) pVar->szAlias );
      }
      hb_xfree( ( void * ) pVar );
   }

   while( pFunc->pMemvars )
   {
      pVar = pFunc->pMemvars;
      pFunc->pMemvars = pVar->pNext;

      hb_xfree( ( void * ) pVar->szName );
      if( pVar->szAlias )
      {
         hb_xfree( ( void * ) pVar->szAlias );
      }
      hb_xfree( ( void * ) pVar );
   }

   hb_xfree( ( void * ) pFunc->pCode );
/* hb_xfree( ( void * ) pFunc->szName ); The name will be released in KillSymbol() */
   hb_xfree( ( void * ) pFunc );

   return pNext;
}


PCOMSYMBOL KillSymbol( PCOMSYMBOL pSym )
{
   PCOMSYMBOL pNext = pSym->pNext;

   hb_xfree( ( void * ) pSym->szName );
   hb_xfree( ( void * ) pSym );

   return pNext;
}

void GenBreak( void )
{
   PushSymbol( yy_strdup("BREAK"), 1 );
   PushNil();
}

void GenExterns( void ) /* generates the symbols for the EXTERN names */
{
   PEXTERN pDelete;

   if( _bDebugInfo )
      AddExtern( yy_strdup( "__DBGENTRY" ) );

   while( pExterns )
   {
      if( GetSymbol( pExterns->szName, NULL ) )
      {
         if( ! GetFuncall( pExterns->szName ) )
            AddFunCall( pExterns->szName );
      }
      else
      {
         AddSymbol( pExterns->szName, NULL );
         AddFunCall( pExterns->szName );
      }
      pDelete  = pExterns;
      pExterns = pExterns->pNext;
      hb_xfree( ( void * ) pDelete );
   }
}

/* This function generates pcodes for IIF( expr1, expr2, expr3 )
 * or IF( expr1, expr2, expr3 )
 *
 * NOTE:
 *   'IF' followed by parenthesized expression containing 3 expressions
 * is always interpreted as IF inlined - it is not possible to distinguish
 * it from IF( expr1, expr2, expr3 ); ENDIF syntax
 * (This behaviour is Clipper compatible)
 */
void GenIfInline( void )
{
   EXPLIST_PTR pExp, pDel;
   int iExpCount = 3;   /* We are expecting 3 expressions here */
   BOOL bGenPCode;

   /* save currently used pcode buffer */
   _pExpList->exprSize  = functions.pLast->lPCodePos;
   _pExpList->exprPCode = functions.pLast->pCode;

   /* find the first expression in the list */
   while( --iExpCount )
      _pExpList = _pExpList->pPrev;

   /* return to the original pcode buffer */
   functions.pLast->pCode      = _pExpList->prevPCode;
   functions.pLast->lPCodeSize = _pExpList->prevSize;
   functions.pLast->lPCodePos  = _pExpList->prevPos;

   /* Update the pointer for nested or next expressions */
   pExp = _pExpList;
   if( _pExpList->pPrev )
   {
      _pExpList = _pExpList->pPrev;
      _pExpList->pNext = NULL;
   }
   else
      _pExpList = NULL;

   bGenPCode = TRUE;
   pDel = pExp;    /* save it for later use */

   /* pExp points now to pcode buffer for logical condition
    */
   if( pExp->exprSize == 0 )
   {
      /* The logical condition have to be specified.
       * If it is empty then generate the syntax error
       */
      GenError( _szCErrors, 'E', ERR_SYNTAX, ",", NULL );
   }
   else if( pExp->exprSize == 1 )
   {
      /* one byte opcode for logical condition - check if it is TRUE or FALSE
       */
      if( pExp->exprPCode[ 0 ] == HB_P_TRUE )
      {
         /* move to the second expression */
         pExp = pExp->pNext;
         if( pExp->exprSize )
            GenPCodeN( pExp->exprPCode, pExp->exprSize );
         else
            PushNil();     /* IIF have to return some value */
         bGenPCode = FALSE;
      }
      else if( pExp->exprPCode[ 0 ] == HB_P_FALSE )
      {
         /* move to the third expression */
         pExp = pExp->pNext;
         pExp = pExp->pNext;
         if( pExp->exprSize )
            GenPCodeN( pExp->exprPCode, pExp->exprSize );
         else
            PushNil();     /* IIF have to return some value */
         bGenPCode = FALSE;
      }
   }

   if( bGenPCode )
   {
      /* generate pcodes for all expressions
       */
      LONG lPosFalse, lPosEnd;

      GenPCodeN( pExp->exprPCode, pExp->exprSize );
      lPosFalse = JumpFalse( 0 );

      pExp = pExp->pNext;
      if( pExp->exprSize )
         GenPCodeN( pExp->exprPCode, pExp->exprSize );
      else
         PushNil();     /* IIF have to return some value */
      lPosEnd = Jump( 0 );
      JumpHere( lPosFalse );

      pExp = pExp->pNext;
      if( pExp->exprSize )
         GenPCodeN( pExp->exprPCode, pExp->exprSize );
      else
         PushNil();     /* IIF have to return some value */
      JumpHere( lPosEnd );
   }

   while( pDel )
   {
      pExp = pDel;
      pDel = pDel->pNext;
      hb_xfree( pExp->exprPCode );
      hb_xfree( pExp );
   }

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pFree;

      if( pStackValType )
      {
         pFree = pStackValType;
         debug_msg( "\n***---IIF()\n", NULL );

         pStackValType = pStackValType->pPrev;
         hb_xfree( ( void * )pFree );
      }
      else
         debug_msg( "\n***IIF() Compile time stack overflow\n", NULL );
   }
}


PFUNCTION GetFuncall( char * szFunctionName ) /* returns a previously called defined function */
{
   PFUNCTION pFunc = funcalls.pFirst;

   while( pFunc )
   {
      if( ! strcmp( pFunc->szName, szFunctionName ) )
         return pFunc;
      else
      {
         if( pFunc->pNext )
            pFunc = pFunc->pNext;
         else
            return NULL;
      }
   }
   return NULL;
}

PFUNCTION GetFunction( char * szFunctionName ) /* returns a previously defined function */
{
   PFUNCTION pFunc = functions.pFirst;

   while( pFunc )
   {
      if( ! strcmp( pFunc->szName, szFunctionName ) )
         return pFunc;
      else
      {
         if( pFunc->pNext )
            pFunc = pFunc->pNext;
         else
            return NULL;
      }
   }
   return NULL;
}

PVAR GetVar( PVAR pVars, WORD wOrder ) /* returns variable if defined or zero */
{
   WORD w = 1;

   while( pVars->pNext && w++ < wOrder )
      pVars = pVars->pNext;

   return pVars;
}

WORD GetVarPos( PVAR pVars, char * szVarName ) /* returns the order + 1 of a variable if defined or zero */
{
   WORD wVar = 1;

   while( pVars )
   {
      if( pVars->szName && ! strcmp( pVars->szName, szVarName ) )
      {
         if( _bWarnings )
         {
            PSTACK_VAL_TYPE pNewStackType;

            pVars->iUsed = 1;

            pNewStackType = ( STACK_VAL_TYPE * )hb_xgrab( sizeof( STACK_VAL_TYPE ) );
            pNewStackType->cType = pVars->cType;
            pNewStackType->pPrev = pStackValType;

            pStackValType = pNewStackType;
            debug_msg( "\n* *GetVarPos()\n", NULL );
         }
         return wVar;
      }
      else
      {
         if( pVars->pNext )
         {
            pVars = pVars->pNext;
            wVar++;
         }
         else
            return 0;
      }
   }
   return 0;
}

int GetLocalVarPos( char * szVarName ) /* returns the order + 1 of a variable if defined or zero */
{
   int iVar = 0;
   PFUNCTION pFunc = functions.pLast;

   if( pFunc->szName )
      /* we are in a function/procedure -we don't need any tricks */
      return GetVarPos( pFunc->pLocals, szVarName );
   else
   {
      /* we are in a codeblock */
      iVar = GetVarPos( pFunc->pLocals, szVarName );
      if( iVar == 0 )
      {
         /* this is not a current codeblock parameter
         * we have to check the list of nested codeblocks up to a function
         * where the codeblock is defined
         */
         PFUNCTION pOutBlock = pFunc;   /* the outermost codeblock */

         pFunc = pFunc->pOwner;
         while( pFunc )
         {
            iVar = GetVarPos( pFunc->pLocals, szVarName );
            if( iVar )
            {
               if( pFunc->pOwner )
               {
                  /* this variable is defined in a parent codeblock
                  * It is not possible to access a parameter of a codeblock in which
                  * the current codeblock is defined
                  */
                  GenError( _szCErrors, 'E', ERR_OUTER_VAR, szVarName, NULL );
               }
               else
               {
                  /* We want to access a local variable defined in a function
                   * that owns this codeblock. We cannot access this variable in
                   * a normal way because at runtime the stack base will point
                   * to local variables of EVAL function.
                   *  The codeblock cannot have static variables then we can
                   * use this structure to store temporarily all referenced
                   * local variables
                   */
                  /* NOTE: The list of local variables defined in a function
                   * and referenced in a codeblock will be stored in a outer
                   * codeblock only. This makes sure that all variables will be
                   * detached properly - the inner codeblock can be created
                   * outside of a function where it was defined when the local
                   * variables are not accessible.
                   */
                  iVar = -GetVarPos( pOutBlock->pStatics, szVarName );
                  if( iVar == 0 )
                  {
                     /* this variable was not referenced yet - add it to the list */
                     PVAR pVar;

                     pVar = ( PVAR ) hb_xgrab( sizeof( VAR ) );
                     pVar->szName = szVarName;
                     pVar->cType = ' ';
                     pVar->iUsed = 0;
                     pVar->pNext  = NULL;

                     /* Use negative order to signal that we are accessing a local
                     * variable from a codeblock
                     */
                     iVar = -1;  /* first variable */
                     if( ! pOutBlock->pStatics )
                        pOutBlock->pStatics = pVar;
                     else
                     {
                        PVAR pLastVar = pOutBlock->pStatics;

                        --iVar;   /* this will be at least second variable */
                        while( pLastVar->pNext )
                        {
                           pLastVar = pLastVar->pNext;
                           --iVar;
                        }
                        pLastVar->pNext = pVar;
                     }
                  }
                  return iVar;
               }
            }
            pOutBlock = pFunc;
            pFunc = pFunc->pOwner;
         }
      }
   }
   return iVar;
}

/*
 * Gets position of passed static variables.
 * All static variables are hold in a single array at runtime then positions
 * are numbered for whole PRG module.
 */
int GetStaticVarPos( char * szVarName )
{
   int iPos;
   PFUNCTION pFunc = functions.pLast;

   /* First we have to check if this name belongs to a static variable
     * defined in current function
     */
   if( pFunc->pOwner )
      pFunc = pFunc->pOwner;  /* we are in the static variable definition state */
   iPos = GetVarPos( pFunc->pStatics, szVarName );
   if( iPos )
      return iPos + pFunc->iStaticsBase;

   /* Next we have to check the list of global static variables
     * Note: It is not possible to have global static variables when
     * implicit starting procedure is defined
     */
   if( !_bStartProc )
   {
      iPos = GetVarPos( functions.pFirst->pStatics, szVarName );
      if( iPos )
         return iPos;
   }
   return 0;
}

/* Checks if passed variable name is declared as FIELD
 * Returns 0 if not found in FIELD list or its position in this list if found
 * It also returns a pointer to the function where this field was declared
 */
int GetFieldVarPos( char * szVarName, PFUNCTION * pOwner )
{
   int iVar;
   PFUNCTION pFunc = functions.pLast;

   *pOwner = NULL;
   if( pFunc->szName )
      /* we are in a function/procedure -we don't need any tricks */
      iVar = GetVarPos( pFunc->pFields, szVarName );
   else
   {
      /* we have to check the list of nested codeblock up to a function
       * where the codeblock is defined
       */
      while( pFunc->pOwner )
         pFunc = pFunc->pOwner;
      iVar = GetVarPos( pFunc->pFields, szVarName );
   }
   /* If not found on the list declared in current function then check
    * the global list (only if there will be no starting procedure)
    */
   if( ! iVar && ! _bStartProc )
   {
      pFunc = functions.pFirst;
      iVar = GetVarPos( pFunc->pFields, szVarName );
   }
   if( iVar )
      *pOwner = pFunc;

   return iVar;
}

/** Checks if passed variable name is declared as FIELD
 * Returns 0 if not found in FIELD list or its position in this list if found
 */
int GetMemvarPos( char * szVarName )
{
   int iVar;
   PFUNCTION pFunc = functions.pLast;

   if( pFunc->szName )
      /* we are in a function/procedure -we don't need any tricks */
      iVar = GetVarPos( pFunc->pMemvars, szVarName );
   else
   {
      /* we have to check the list of nested codeblock up to a function
       * where the codeblock is defined
       */
      while( pFunc->pOwner )
         pFunc = pFunc->pOwner;
      iVar = GetVarPos( pFunc->pMemvars, szVarName );
   }
   /* if not found on the list declared in current function then check
    * the global list (only if there will be no starting procedure)
    */
   if( ! iVar && ! _bStartProc )
      iVar = GetVarPos( functions.pFirst->pMemvars, szVarName );

   return iVar;
}

WORD FixSymbolPos( WORD wCompilePos )
{
   return ( _bStartProc ? wCompilePos - 1 : wCompilePos - 2 );
}


/* returns a symbol pointer from the symbol table
 * and sets its position in the symbol table
 */
PCOMSYMBOL GetSymbol( char * szSymbolName, WORD * pwPos )
{
   PCOMSYMBOL pSym = symbols.pFirst;
   WORD wCnt = 1;

   if( pwPos )
      *pwPos = 0;
   while( pSym )
   {
      if( ! strcmp( pSym->szName, szSymbolName ) )
      {
         if( pwPos )
            *pwPos = wCnt;
         return pSym;
      }
      else
      {
         if( pSym->pNext )
         {
            pSym = pSym->pNext;
            ++wCnt;
         }
         else
            return NULL;
      }
   }
   return NULL;
}

PCOMSYMBOL GetSymbolOrd( WORD wSymbol )   /* returns a symbol based on its index on the symbol table */
{
   PCOMSYMBOL pSym = symbols.pFirst;
   WORD w = 1;

   while( w++ < wSymbol && pSym->pNext )
      pSym = pSym->pNext;

   return pSym;
}

WORD GetFunctionPos( char * szFunctionName ) /* return 0 if not found or order + 1 */
{
   PFUNCTION pFunc = functions.pFirst;
   WORD wFunction = _bStartProc;

   while( pFunc )
   {
      if( ! strcmp( pFunc->szName, szFunctionName ) && pFunc != functions.pFirst )
         return wFunction;
      else
      {
         if( pFunc->pNext )
         {
            pFunc = pFunc->pNext;
            wFunction++;
         }
         else
            return 0;
      }
   }
   return 0;
}

void Inc( void )
{
   GenPCode1( HB_P_INC );

   if( _bWarnings )
   {
      if( pStackValType )
      {
         if(  pStackValType->cType == ' ' )
            GenWarning( _szCWarnings, 'W', WARN_NUMERIC_SUSPECT, NULL, NULL );
         else if( pStackValType->cType != 'N' )
         {
            char sType[ 2 ];

            sType[ 0 ] = pStackValType->cType;
            sType[ 1 ] = '\0';

            GenWarning( _szCWarnings, 'W', WARN_NUMERIC_TYPE, sType, NULL );
         }
      }
      else
         debug_msg( "\n* *Inc() Compile time stack overflow\n", NULL );
   }
}

ULONG Jump( LONG lOffset )
{
   /* TODO: We need a longer offset (longer then two bytes)
    */
   if( lOffset < ( LONG ) SHRT_MIN || lOffset > ( LONG ) SHRT_MAX )
      GenError( _szCErrors, 'E', ERR_JUMP_TOO_LONG, NULL, NULL );

   GenPCode3( HB_P_JUMP, LOBYTE( lOffset ), HIBYTE( lOffset ) );

   return functions.pLast->lPCodePos - 2;
}

ULONG JumpFalse( LONG lOffset )
{
   /* TODO: We need a longer offset (longer then two bytes)
    */
   if( lOffset < ( LONG ) SHRT_MIN || lOffset > ( LONG ) SHRT_MAX )
      GenError( _szCErrors, 'E', ERR_JUMP_TOO_LONG, NULL, NULL );

   GenPCode3( HB_P_JUMPFALSE, LOBYTE( lOffset ), HIBYTE( lOffset ) );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pFree;
      char sType[ 2 ];

      if( pStackValType )
      {
         sType[ 0 ] = pStackValType->cType;
         sType[ 1 ] = '\0';
      }
      else
         debug_msg( "\n* *HB_P_JUMPFALSE Compile time stack overflow\n", NULL );

      /* compile time Operand value */
      if( pStackValType && pStackValType->cType == ' ' )
         GenWarning( _szCWarnings, 'W', WARN_LOGICAL_SUSPECT, NULL, NULL );
      else if( pStackValType && pStackValType->cType != 'L')
         GenWarning( _szCWarnings, 'W', WARN_LOGICAL_TYPE, sType, NULL );

      /* compile time assignment value has to be released */
      pFree = pStackValType;
      debug_msg( "\n* *---JampFalse()\n", NULL );

      if( pStackValType )
      {
         pStackValType = pStackValType->pPrev;
      }

      if( pFree )
      {
         hb_xfree( ( void * ) pFree );
      }
   }

   return functions.pLast->lPCodePos - 2;
}

void JumpThere( ULONG ulFrom, ULONG ulTo )
{
   BYTE * pCode = functions.pLast->pCode;
   LONG lOffset = ulTo - ulFrom + 1;

   /* TODO: We need a longer offset (longer then two bytes)
    */
   if( lOffset < ( LONG ) SHRT_MIN || lOffset > ( LONG ) SHRT_MAX )
      GenError( _szCErrors, 'E', ERR_JUMP_TOO_LONG, NULL, NULL );

   pCode[ ( ULONG ) ulFrom ]     = LOBYTE( lOffset );
   pCode[ ( ULONG ) ulFrom + 1 ] = HIBYTE( lOffset );
}

void JumpHere( ULONG ulOffset )
{
   JumpThere( ulOffset, functions.pLast->lPCodePos );
}

ULONG JumpTrue( LONG lOffset )
{
   /* TODO: We need a longer offset (longer then two bytes)
    */
   if( lOffset < ( LONG ) SHRT_MIN || lOffset > ( LONG ) SHRT_MAX )
      GenError( _szCErrors, 'E', ERR_JUMP_TOO_LONG, NULL, NULL );
   GenPCode3( HB_P_JUMPTRUE, LOBYTE( lOffset ), HIBYTE( lOffset ) );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pFree;
      char sType[ 2 ];

      if( pStackValType )
      {
         sType[ 0 ] = pStackValType->cType;
         sType[ 1 ] = '\0';
      }
      else
         debug_msg( "\n* *HB_P_JUMPTRUE Compile time stack overflow\n", NULL );

      /* compile time Operand value */
      if( pStackValType && pStackValType->cType == ' ' )
         GenWarning( _szCWarnings, 'W', WARN_LOGICAL_SUSPECT, NULL, NULL );
      else if( pStackValType && pStackValType->cType != 'L')
         GenWarning( _szCWarnings, 'W', WARN_LOGICAL_TYPE, sType, NULL );

      /* compile time assignment value has to be released */
      pFree = pStackValType;
      debug_msg( "\n* *---JampTrue() \n", NULL );

      if( pStackValType )
      {
         pStackValType = pStackValType->pPrev;
      }

      if( pFree )
      {
         hb_xfree( ( void * ) pFree );
      }
   }

   return functions.pLast->lPCodePos - 2;
}

void Line( void ) /* generates the pcode with the currently compiled source code line */
{
   if( _bLineNumbers && ! _bDontGenLineNum )
   {
      if( ( ( functions.pLast->lPCodePos - _ulLastLinePos ) > 3 ) || _bDebugInfo )
      {
         _ulLastLinePos = functions.pLast->lPCodePos;
         GenPCode3( HB_P_LINE, LOBYTE( iLine ), HIBYTE( iLine ) );
      }
      else
      {
         functions.pLast->pCode[ _ulLastLinePos +1 ] = LOBYTE( iLine );
         functions.pLast->pCode[ _ulLastLinePos +2 ] = HIBYTE( iLine );
      }
   }
   _bDontGenLineNum = FALSE;
}

/* Generates the pcode with the currently compiled source code line
 * if debug code was requested only
 */
void LineDebug( void )
{
   if( _bDebugInfo )
      Line();
}

void LineBody( void ) /* generates the pcode with the currently compiled source code line */
{
   /* This line can be placed inside a procedure or function only */
   /* except EXTERNAL */
   if( _iState != EXTERN )
   {
      if( ! _bStartProc && functions.iCount <= 1 )
      {
         GenError( _szCErrors, 'E', ERR_OUTSIDE, NULL, NULL );
      }
   }

   functions.pLast->bFlags |= FUN_STATEMENTS;
   Line();
}

/**
 * Function generates passed pcode for passed variable name
 */
void VariablePCode( BYTE bPCode, char * szVarName )
{
   WORD wVar;
   PCOMSYMBOL pSym;
   PFUNCTION pOwnerFunc = NULL;

   if( _bForceMemvars )
   {  /* -v swith was used -> first check the MEMVARs */
      wVar = GetMemvarPos( szVarName );
      if( ! wVar )
      {
         wVar = GetFieldVarPos( szVarName, &pOwnerFunc );
         if( ! wVar )
            GenWarning( _szCWarnings, 'W', ( ( bPCode == HB_P_POPMEMVAR ) ? WARN_MEMVAR_ASSUMED : WARN_AMBIGUOUS_VAR ),
                  szVarName, NULL );
      }
   }
   else
   {  /* -v was not used -> default action is checking FIELDs list */
      wVar = GetFieldVarPos( szVarName, &pOwnerFunc );
      if( wVar == 0 )
      {
         wVar = GetMemvarPos( szVarName );
         if( wVar == 0 )
            GenWarning( _szCWarnings, 'W', ( ( bPCode == HB_P_POPMEMVAR ) ? WARN_MEMVAR_ASSUMED : WARN_AMBIGUOUS_VAR ),
                  szVarName, NULL );
      }
   }

   if( wVar && pOwnerFunc )
   {  /* variable is declared using FIELD statement */
      PVAR pField = GetVar( pOwnerFunc->pFields, wVar );

      if( pField->szAlias )
      {  /* the alias was specified too */
         if( bPCode == HB_P_POPMEMVAR )
            bPCode = HB_P_POPALIASEDFIELD;
         else if( bPCode == HB_P_PUSHMEMVAR )
            bPCode = HB_P_PUSHALIASEDFIELD;
         else
            /* pushing fields by reference is not allowed */
            GenError( _szCErrors, 'E', ERR_INVALID_REFER, szVarName, NULL );
         PushSymbol( yy_strdup( pField->szAlias ), 0 );
      }
      else
      {  /* this is unaliased field */
         if( bPCode == HB_P_POPMEMVAR )
            bPCode = HB_P_POPFIELD;
         else if( bPCode == HB_P_PUSHMEMVAR )
            bPCode = HB_P_PUSHFIELD;
         else
            /* pushing fields by reference is not allowed */
            GenError( _szCErrors, 'E', ERR_INVALID_REFER, szVarName, NULL );
      }
   }

   pSym = GetSymbol( szVarName, &wVar );
   if( ! pSym )
      pSym = AddSymbol( szVarName, &wVar );
   pSym->cScope |= VS_MEMVAR;
   GenPCode3( bPCode, LOBYTE( wVar ), HIBYTE( wVar ) );
}

void Message( char * szMsgName )       /* sends a message to an object */
{
   WORD wSym;
   PCOMSYMBOL pSym = GetSymbol( szMsgName, &wSym );

   if( ! pSym )  /* the symbol was not found on the symbol table */
      pSym = AddSymbol( szMsgName, &wSym );
   pSym->cScope |= FS_MESSAGE;
   GenPCode3( HB_P_MESSAGE, LOBYTE( wSym ), HIBYTE( wSym ) );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pNewStackType;
      char cType;

      cType = pSym->cType;

      pNewStackType = ( STACK_VAL_TYPE * )hb_xgrab( sizeof( STACK_VAL_TYPE ) );
      pNewStackType->cType = cType;
      pNewStackType->pPrev = pStackValType;
      pStackValType = pNewStackType;

      pStackValType->cType = cType;
      debug_msg( "\n***Message()\n", NULL );
   }
}

void MessageDupl( char * szMsgName )  /* fix a generated message and duplicate to an object */
{
   WORD wSetSym;
   PCOMSYMBOL pSym;
   BYTE bLoGetSym, bHiGetSym;           /* get symbol */
   PFUNCTION pFunc = functions.pLast;   /* get the currently defined Clipper function */

   pSym = GetSymbol( szMsgName, &wSetSym );
   if( ! pSym )  /* the symbol was not found on the symbol table */
      pSym = AddSymbol( szMsgName, &wSetSym );
   pSym->cScope |= FS_MESSAGE;
                                        /* Get previously generated message */
   bLoGetSym = pFunc->pCode[ _ulMessageFix + 1];
   bHiGetSym = pFunc->pCode[ _ulMessageFix + 2];

   pFunc->pCode[ _ulMessageFix + 1 ] = LOBYTE( wSetSym );
   pFunc->pCode[ _ulMessageFix + 2 ] = HIBYTE( wSetSym );

   pFunc->lPCodePos -= 3;               /* Remove unnecessary function call  */
   Duplicate();                         /* Duplicate object                  */
   GenPCode3( HB_P_MESSAGE, bLoGetSym, bHiGetSym );
                                        /* Generate new message              */
}

void MessageFix( char * szMsgName )  /* fix a generated message to an object */
{
   WORD wSym;
   PCOMSYMBOL pSym;
   PFUNCTION pFunc = functions.pLast;   /* get the currently defined Clipper function */

   pSym = GetSymbol( szMsgName, &wSym );
   if( ! pSym )  /* the symbol was not found on the symbol table */
      pSym = AddSymbol( szMsgName, &wSym );
   pSym->cScope |= FS_MESSAGE;

   pFunc->pCode[ _ulMessageFix + 1 ] = LOBYTE( wSym );
   pFunc->pCode[ _ulMessageFix + 2 ] = HIBYTE( wSym );
   pFunc->lPCodePos -= 3;        /* Remove unnecessary function call */
}

void PopId( char * szVarName ) /* generates the pcode to pop a value from the virtual machine stack onto a variable */
{
   int iVar;

   if( pAliasId == NULL )
   {
      iVar = GetLocalVarPos( szVarName );
      if( iVar )
         GenPCode3( HB_P_POPLOCAL, LOBYTE( iVar ), HIBYTE( iVar ) );
      else
      {
         iVar = GetStaticVarPos( szVarName );
         if( iVar )
         {
            GenPCode3( HB_P_POPSTATIC, LOBYTE( iVar ), HIBYTE( iVar ) );
            functions.pLast->bFlags |= FUN_USES_STATICS;
         }
         else
         {
            VariablePCode( HB_P_POPMEMVAR, szVarName );
         }
      }
   }
   else
   {
      if( pAliasId->type == ALIAS_NAME )
      {
         if( pAliasId->alias.szAlias[ 0 ] == 'M' && pAliasId->alias.szAlias[ 1 ] == '\0' )
         {  /* M->variable */
            VariablePCode( HB_P_POPMEMVAR, szVarName );
         }
         else
         {
            int iCmp = strncmp( pAliasId->alias.szAlias, "MEMVAR", 4 );
            if( iCmp == 0 )
                  iCmp = strncmp( pAliasId->alias.szAlias, "MEMVAR", strlen( pAliasId->alias.szAlias ) );
            if( iCmp == 0 )
            {  /* MEMVAR-> or MEMVA-> or MEMV-> */
               VariablePCode( HB_P_POPMEMVAR, szVarName );
            }
            else
            {  /* field variable */
               iCmp = strncmp( pAliasId->alias.szAlias, "FIELD", 4 );
               if( iCmp == 0 )
                  iCmp = strncmp( pAliasId->alias.szAlias, "FIELD", strlen( pAliasId->alias.szAlias ) );
               if( iCmp == 0 )
               {  /* FIELD-> */
                  FieldPCode( HB_P_POPFIELD, szVarName );
               }
               else
               {  /* database alias */
                  PushSymbol( yy_strdup( pAliasId->alias.szAlias ), 0 );
                  FieldPCode( HB_P_POPALIASEDFIELD, szVarName );
               }
            }
         }
      }
      else if( pAliasId->type == ALIAS_NUMBER )
      {
         PushInteger( pAliasId->alias.iAlias );
         FieldPCode( HB_P_POPALIASEDFIELD, szVarName );
      }
      else
         /* Alias is already placed on stack */
         FieldPCode( HB_P_POPALIASEDFIELD, szVarName );
   }


   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pVarType, pFree;
      char sType[ 2 ];

      /* Just pushed by Get...Pos() */
      pVarType = pStackValType;

      if( pVarType )
      {
         sType[ 0 ] = pVarType->cType;
         sType[ 1 ] = '\0';

         /* skip back to the assigned value */
         pStackValType = pStackValType->pPrev;
      }
      else
         debug_msg( "\n***PopId() Compile time stack overflow\n", NULL );

      if( pVarType && pStackValType && pVarType->cType != ' ' && pStackValType->cType == ' ' )
         GenWarning( _szCWarnings, 'W', WARN_ASSIGN_SUSPECT, szVarName, sType );
      else if( pVarType && pStackValType && pVarType->cType != ' ' && pVarType->cType != pStackValType->cType )
         GenWarning( _szCWarnings, 'W', WARN_ASSIGN_TYPE, szVarName, sType );

      /* compile time variable has to be released */
      if( pVarType )
      {
         hb_xfree( ( void * ) pVarType );
      }

      debug_msg( "\n***--- Var at PopId()\n", NULL );

      /* compile time assignment value has to be released */
      pFree = pStackValType;
      debug_msg( "\n***--- Value at PopId()\n", NULL );

      if( pStackValType )
      {
         pStackValType = pStackValType->pPrev;
      }
      else
      {
         debug_msg( "\n***PopId() Compile time stack overflow\n", NULL );
      }

      if( pFree )
      {
         hb_xfree( ( void * ) pFree );
      }
   }
}

void PushId( char * szVarName ) /* generates the pcode to push a variable value to the virtual machine stack */
{
   int iVar;

   if( pAliasId == NULL )
   {
      if( iVarScope == VS_STATIC && functions.pLast->szName )
      {
      /* Reffering to any variable is not allowed during initialization
         * of static variable
         */
         _pInitFunc->bFlags |= FUN_ILLEGAL_INIT;
      }

      iVar = GetLocalVarPos( szVarName );
      if( iVar )
         GenPCode3( HB_P_PUSHLOCAL, LOBYTE( iVar ), HIBYTE( iVar ) );
      else
      {
         iVar = GetStaticVarPos( szVarName );
         if( iVar )
         {
            GenPCode3( HB_P_PUSHSTATIC, LOBYTE( iVar ), HIBYTE( iVar ) );
            functions.pLast->bFlags |= FUN_USES_STATICS;
         }
         else
         {
            VariablePCode( HB_P_PUSHMEMVAR, szVarName );
         }
      }
   }
   else
   {
      if( pAliasId->type == ALIAS_NAME )
      {
         if( pAliasId->alias.szAlias[ 0 ] == 'M' && pAliasId->alias.szAlias[ 1 ] == '\0' )
         {  /* M->variable */
            VariablePCode( HB_P_PUSHMEMVAR, szVarName );
         }
         else
         {
            int iCmp = strncmp( pAliasId->alias.szAlias, "MEMVAR", 4 );
            if( iCmp == 0 )
                  iCmp = strncmp( pAliasId->alias.szAlias, "MEMVAR", strlen( pAliasId->alias.szAlias ) );
            if( iCmp == 0 )
            {  /* MEMVAR-> or MEMVA-> or MEMV-> */
               VariablePCode( HB_P_PUSHMEMVAR, szVarName );
            }
            else
            {  /* field variable */
               iCmp = strncmp( pAliasId->alias.szAlias, "FIELD", 4 );
               if( iCmp == 0 )
                  iCmp = strncmp( pAliasId->alias.szAlias, "FIELD", strlen( pAliasId->alias.szAlias ) );
               if( iCmp == 0 )
               {  /* FIELD-> */
                  FieldPCode( HB_P_PUSHFIELD, szVarName );
               }
               else
               {  /* database alias */
                  PushSymbol( yy_strdup( pAliasId->alias.szAlias ), 0 );
                  FieldPCode( HB_P_PUSHALIASEDFIELD, szVarName );
               }
            }
         }
      }
      else if( pAliasId->type == ALIAS_NUMBER )
      {
         PushInteger( pAliasId->alias.iAlias );
         FieldPCode( HB_P_PUSHALIASEDFIELD, szVarName );
      }
      else
         /* Alias is already placed on stack */
         FieldPCode( HB_P_PUSHALIASEDFIELD, szVarName );
   }

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pNewStackType;

      pNewStackType = ( STACK_VAL_TYPE * ) hb_xgrab( sizeof( STACK_VAL_TYPE ) );
      pNewStackType->cType = cVarType;
      pNewStackType->pPrev = pStackValType;

      pStackValType = pNewStackType;
      debug_msg( "\n***HB_P_PUSHMEMVAR\n ", NULL );
   }
}

void PushIdByRef( char * szVarName ) /* generates the pcode to push a variable by reference to the virtual machine stack */
{
   WORD iVar;

   if( iVarScope == VS_STATIC && functions.pLast->szName )
   {
     /* Reffering to any variable is not allowed during initialization
      * of static variable
      */
      _pInitFunc->bFlags |= FUN_ILLEGAL_INIT;
   }

   iVar = GetLocalVarPos( szVarName );
   if( iVar )
      GenPCode3( HB_P_PUSHLOCALREF, LOBYTE( iVar ), HIBYTE( iVar ) );
   else
   {
      iVar = GetStaticVarPos( szVarName );
      if( iVar )
      {
         GenPCode3( HB_P_PUSHSTATICREF, LOBYTE( iVar ), HIBYTE( iVar ) );
         functions.pLast->bFlags |= FUN_USES_STATICS;
      }
      else
      {
         VariablePCode( HB_P_PUSHMEMVARREF, szVarName );
      }
   }
}

void PushLogical( int iTrueFalse ) /* pushes a logical value on the virtual machine stack */
{
   if( iTrueFalse )
      GenPCode1( HB_P_TRUE );
   else
      GenPCode1( HB_P_FALSE );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pNewStackType;

      pNewStackType = ( STACK_VAL_TYPE * )hb_xgrab( sizeof( STACK_VAL_TYPE ) );
      pNewStackType->cType = 'L';
      pNewStackType->pPrev = pStackValType;

      pStackValType = pNewStackType;
      debug_msg( "\n***PushLogical()\n", NULL );
   }
}

void PushNil( void )
{
   GenPCode1( HB_P_PUSHNIL );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pNewStackType;

      pNewStackType = ( STACK_VAL_TYPE * )hb_xgrab( sizeof( STACK_VAL_TYPE ) );
      pNewStackType->cType = ' ' /*TODO maybe 'U'*/ ;
      pNewStackType->pPrev = pStackValType;

      pStackValType = pNewStackType;
      debug_msg( "\n***PushNil()\n", NULL );
   }
}

/* generates the pcode to push a double number on the virtual machine stack */
void PushDouble( double dNumber, BYTE bDec )
{
   GenPCode1( HB_P_PUSHDOUBLE );
   GenPCodeN( ( BYTE * ) &dNumber, sizeof( double ) );
   GenPCode1( bDec );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pNewStackType;

      pNewStackType = ( STACK_VAL_TYPE * )hb_xgrab( sizeof( STACK_VAL_TYPE ) );
      pNewStackType->cType = 'N';
      pNewStackType->pPrev = pStackValType;

      pStackValType = pNewStackType;
      debug_msg( "\n***PushDouble()\n", NULL );
   }
}

void PushFunCall( char * szFunName )
{
   char * szFunction;

   szFunction = RESERVED_FUNC( szFunName );
   if( szFunction )
   {
      /* Abbreviated function name was used - change it for whole name
       */
      PushSymbol( yy_strdup( szFunction ), 1 );
   }
   else
      PushSymbol( szFunName, 1 );
   PushNil();
}

/* generates the pcode to push a integer number on the virtual machine stack */
void PushInteger( int iNumber )
{
   if( iNumber )
      GenPCode3( HB_P_PUSHINT, LOBYTE( ( WORD ) iNumber ), HIBYTE( ( WORD ) iNumber ) );
   else
      GenPCode1( HB_P_ZERO );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pNewStackType;

      pNewStackType = ( STACK_VAL_TYPE * )hb_xgrab( sizeof( STACK_VAL_TYPE ) );
      pNewStackType->cType = 'N';
      pNewStackType->pPrev = pStackValType;

      pStackValType = pNewStackType;
      debug_msg( "\n***PushInteger() %i\n ", iNumber );
   }
}

/* generates the pcode to push a long number on the virtual machine stack */
void PushLong( long lNumber )
{
   if( lNumber )
   {
      GenPCode1( HB_P_PUSHLONG );
      GenPCode1( ( ( char * ) &lNumber )[ 0 ] );
      GenPCode1( ( ( char * ) &lNumber )[ 1 ] );
      GenPCode1( ( ( char * ) &lNumber )[ 2 ] );
      GenPCode1( ( ( char * ) &lNumber )[ 3 ] );
   }
   else
      GenPCode1( HB_P_ZERO );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pNewStackType;

      pNewStackType = ( STACK_VAL_TYPE * )hb_xgrab( sizeof( STACK_VAL_TYPE ) );
      pNewStackType->cType = 'N';
      pNewStackType->pPrev = pStackValType;

      pStackValType = pNewStackType;
      debug_msg( "\n***PushLong()\n", NULL );
   }
}

/* generates the pcode to push a string on the virtual machine stack */
void PushString( char * szText )
{
   int iStrLen = strlen( szText );

   GenPCode3( HB_P_PUSHSTR, LOBYTE( iStrLen ), HIBYTE( iStrLen ) );
   GenPCodeN( ( BYTE * ) szText, iStrLen );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pNewStackType;

      pNewStackType = ( STACK_VAL_TYPE * )hb_xgrab( sizeof( STACK_VAL_TYPE ) );
      pNewStackType->cType = 'C';
      pNewStackType->pPrev = pStackValType;

      pStackValType = pNewStackType;
      debug_msg( "\n***PushString()\n", NULL );
   }
}

/* generates the pcode to push a symbol on the virtual machine stack */
void PushSymbol( char * szSymbolName, int iIsFunction )
{
   WORD wSym;
   PCOMSYMBOL pSym;

   if( iIsFunction )
   {
      char * pName = RESERVED_FUNC( szSymbolName );
      /* If it is reserved function name then we should truncate
       * the requested name.
       * We have to use passed szSymbolName so we can latter deallocate it
       * (pName points to static data)
       */
      if( pName )
         szSymbolName[ strlen( pName ) ] ='\0';
   }

   pSym = GetSymbol( szSymbolName, &wSym );
   if( ! pSym )  /* the symbol was not found on the symbol table */
   {
      pSym = AddSymbol( szSymbolName, &wSym );
      if( iIsFunction )
         AddFunCall( szSymbolName );
   }
   else
   {
      if( iIsFunction && ! GetFuncall( szSymbolName ) )
         AddFunCall( szSymbolName );
   }
   GenPCode3( HB_P_PUSHSYM, LOBYTE( wSym ), HIBYTE( wSym ) );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pNewStackType;
      char cType;

      if( iIsFunction )
         cType = pSym->cType;
      else
         cType = cVarType;

      pNewStackType = ( STACK_VAL_TYPE * )hb_xgrab( sizeof( STACK_VAL_TYPE ) );
      pNewStackType->cType = cType;
      pNewStackType->pPrev = pStackValType;

      pStackValType = pNewStackType;
      debug_msg( "\n***PushSymbol()\n", NULL );
   }
}

void CheckDuplVars( PVAR pVar, char * szVarName, int iVarScope )
{
   while( pVar )
   {
      if( ! strcmp( pVar->szName, szVarName ) )
      {
         if( ! ( iVarScope & VS_PARAMETER ) )
            --iLine;
         GenError( _szCErrors, 'E', ERR_VAR_DUPL, szVarName, NULL );
      }
      else
         pVar = pVar->pNext;
   }
}

void Dec( void )
{
   GenPCode1( HB_P_DEC );

   if( _bWarnings )
   {
      if( pStackValType )
      {
         if( pStackValType->cType == ' ' )
            GenWarning( _szCWarnings, 'W', WARN_NUMERIC_SUSPECT, NULL, NULL );
         else if( pStackValType->cType != 'N' )
         {
            char sType[ 2 ];

            sType[ 0 ] = pStackValType->cType;
            sType[ 1 ] = '\0';

            GenWarning( _szCWarnings, 'W', WARN_NUMERIC_TYPE, sType, NULL );
         }
      }
      else
         debug_msg( "\n***Dec() Compile time stack overflow\n", NULL );
   }
}

void DimArray( int iDimensions )
{
   GenPCode3( HB_P_DIMARRAY, LOBYTE( iDimensions ), HIBYTE( iDimensions ) );
}

void Do( BYTE bParams )
{
   GenPCode3( HB_P_DO, bParams, 0 );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pFree;
      int i;

      /* Releasing the compile time stack items used as parameters to the function. */
      for( i = abs( bParams ); i > 0; i-- )
      {
         pFree = pStackValType;
         debug_msg( "\n***---Do() \n", NULL );

         if( pStackValType )
            pStackValType = pStackValType->pPrev;
         else
            debug_msg( "\n***Do() Compile time stack overflow\n", NULL );

         if( pFree )
         {
            hb_xfree( ( void * ) pFree );
         }
      }

      /* releasing the compile time Nil symbol terminator */
      pFree = pStackValType;
      debug_msg( "\n***---Do()\n", NULL );
      if( pStackValType )
         pStackValType = pStackValType->pPrev;
      else
         debug_msg( "\n***Do(2) Compile time stack overflow\n", NULL );

      if( pFree )
      {
         hb_xfree( ( void * ) pFree );
      }

      /* releasing the compile time procedure value */
      pFree = pStackValType;
      debug_msg( "\n***---Do() \n", NULL );

      if( pStackValType )
      {
         pStackValType = pStackValType->pPrev;
      }

      if( pFree )
      {
         hb_xfree( ( void * ) pFree );
      }
   }
}

void FixElseIfs( void * pFixElseIfs )
{
   PELSEIF pFix = ( PELSEIF ) pFixElseIfs;

   while( pFix )
   {
      JumpHere( pFix->ulOffset );
      pFix = pFix->pNext;
   }
}

void FixReturns( void ) /* fixes all last defined function returns jumps offsets */
{
   if( _bWarnings && functions.pLast )
   {
      PVAR pVar;

      pVar = functions.pLast->pLocals;
      while( pVar )
      {
         if( pVar->szName && functions.pLast->szName && functions.pLast->szName[0] && ! pVar->iUsed )
            GenWarning( _szCWarnings, 'W', WARN_VAR_NOT_USED, pVar->szName, functions.pLast->szName );

         pVar = pVar->pNext;
      }

      pVar = functions.pLast->pStatics;
      while( pVar )
      {
         if( pVar->szName && functions.pLast->szName && functions.pLast->szName[0] && ! pVar->iUsed )
            GenWarning( _szCWarnings, 'W', WARN_VAR_NOT_USED, pVar->szName, functions.pLast->szName );

         pVar = pVar->pNext;
      }

      /* Clear the compile time stack values (should be empty at this point) */
      while( pStackValType )
      {
         PSTACK_VAL_TYPE pFree;

         debug_msg( "\n***Compile time stack underflow - type: %c\n", pStackValType->cType );
         pFree = pStackValType;
         pStackValType = pStackValType->pPrev;
         hb_xfree( ( void * ) pFree );
      }
      pStackValType = NULL;
   }

/* TODO: check why it triggers this error in keywords.prg
   if( pLoops )
   {
      PTR_LOOPEXIT pLoop = pLoops;
      char cLine[ 64 ];

      while( pLoop->pNext )
         pLoop = pLoop->pNext;

      itoa( pLoop->iLine, cLine, 10 );
      GenError( _szCErrors, 'E', ERR_UNCLOSED_STRU, cLine, NULL );
   }
*/
}

void Function( BYTE bParams )
{
   GenPCode3( HB_P_FUNCTION, bParams, 0 );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pFree;
      int i;

      /* Releasing the compile time stack items used as parameters to the function. */
      for( i = abs( bParams ); i > 0; i-- )
      {
         pFree = pStackValType;
         debug_msg( "\n***---Function() parameter %i \n", i );

         if( pStackValType )
            pStackValType = pStackValType->pPrev;
         else
            debug_msg( "\n***Function() parameter %i Compile time stack overflow\n", i );

         if( pFree )
         {
            hb_xfree( ( void * ) pFree );
         }
      }

      /* releasing the compile time Nil symbol terminator */
      pFree = pStackValType;
      debug_msg( "\n***---NIL at Function()\n", NULL );

      if( pStackValType )
      {
         pStackValType = pStackValType->pPrev;
      }

      if( pFree )
      {
         hb_xfree( ( void * ) pFree );
      }
   }
}

void GenArray( int iElements )
{
   GenPCode3( HB_P_GENARRAY, LOBYTE( iElements ), HIBYTE( iElements ) );

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pFree;
      int iIndex;

      /* Releasing the stack items used by the _GENARRAY (other than the 1st element). */
      for( iIndex = iElements; iIndex > 1; iIndex-- )
      {
         pFree = pStackValType;
         debug_msg( "\n***---element %i at GenArray()\n", wIndex );

         if( pStackValType )
            pStackValType = pStackValType->pPrev;
         else
            debug_msg( "\n***GenArray() Compile time stack overflow\n", NULL );

         if( pFree )
         {
            hb_xfree( ( void * ) pFree );
         }
      }

      if( iElements == 0 )
      {
         PSTACK_VAL_TYPE pNewStackType;

         pNewStackType = ( STACK_VAL_TYPE * )hb_xgrab( sizeof( STACK_VAL_TYPE ) );
         pNewStackType->cType = 'A';
         pNewStackType->pPrev = pStackValType;

         pStackValType = pNewStackType;
         debug_msg( "\n***empty array in GenArray()\n ", NULL );
      }

      /* Using the either remaining 1st element place holder or a new item if empty array. */
      if( pStackValType )
         pStackValType->cType = 'A';
      else
         debug_msg( "\n***ArrrayGen() Compile time stack overflow\n", NULL );
   }
}

void GenPCode1( BYTE byte )
{
   PFUNCTION pFunc = functions.pLast;   /* get the currently defined Clipper function */

   /* Releasing value consumed by HB_P_ARRAYPUT */
   if( _bWarnings )
   {
      if( byte == HB_P_PUSHSELF )
      {
         PSTACK_VAL_TYPE pNewStackType;

         pNewStackType = ( STACK_VAL_TYPE * )hb_xgrab( sizeof( STACK_VAL_TYPE ) );
         pNewStackType->cType = 'O';
         pNewStackType->pPrev = pStackValType;

         pStackValType = pNewStackType;
         debug_msg( "\n***HB_P_PUSHSELF\n", NULL );
      }
      else if( byte == HB_P_ARRAYPUT )
      {
         PSTACK_VAL_TYPE pFree;

         /* Releasing compile time assignment value */
         pFree = pStackValType;
         debug_msg( "\n***---ArrayPut()\n", NULL );

         if( pStackValType )
            pStackValType = pStackValType->pPrev;
         else
            debug_msg( "\n***HB_P_ARRAYPUT Compile time stack overflow\n", NULL );

         if( pFree )
         {
            hb_xfree( ( void * ) pFree );
         }

         /* Releasing compile time array element index value */
         pFree = pStackValType;
         debug_msg( "\n***---HB_P_ARRAYPUT\n", NULL );

         if( pStackValType )
            pStackValType = pStackValType->pPrev;
         else
            debug_msg( "\n***HB_P_ARRAYPUT2 Compile time stack overflow\n", NULL );

         if( pFree )
         {
            hb_xfree( ( void * ) pFree );
         }
      }
      else if( byte == HB_P_POP || byte == HB_P_RETVALUE || byte == HB_P_FORTEST || byte == HB_P_ARRAYAT )
      {
         PSTACK_VAL_TYPE pFree;

         pFree = pStackValType;
         debug_msg( "\n***---HB_P_POP / HB_P_RETVALUE / HB_P_FORTEST / HB_P_ARRAYAT pCode: %i\n", byte );

         if( pStackValType )
            pStackValType = pStackValType->pPrev;
         else
            debug_msg( "\n***pCode: %i Compile time stack overflow\n", byte );

         if( pFree )
         {
            hb_xfree( ( void * ) pFree );
         }
      }
      else if( byte == HB_P_MULT || byte == HB_P_DIVIDE || byte == HB_P_MODULUS || byte == HB_P_POWER || byte == HB_P_NEGATE )
      {
         PSTACK_VAL_TYPE pOperand1 = NULL, pOperand2;
         char sType1[ 2 ], sType2[ 2 ];

         /* 2nd. Operand (stack top)*/
         pOperand2 = pStackValType;

         /* skip back to the 1st. operand */
         if( pOperand2 )
         {
            pOperand1 = pOperand2->pPrev;
            sType2[ 0 ] = pOperand1->cType;
            sType2[ 1 ] = '\0';
         }
         else
            debug_msg( "\n***HB_P_MULT pCode: %i Compile time stack overflow\n", byte );

         /* skip back to the 1st. operand */
         if( pOperand1 )
         {
            sType1[ 0 ] = pOperand1->cType;
            sType1[ 1 ] = '\0';
         }
         else
            debug_msg( "\n***HB_P_MULT2 pCode: %i Compile time stack overflow\n", byte );

         if( pOperand1 && pOperand1->cType != 'N' && pOperand1->cType != ' ' )
            GenWarning( _szCWarnings, 'W', WARN_NUMERIC_TYPE, sType1, NULL );
         else if( pOperand1 && pOperand1->cType == ' ' )
            GenWarning( _szCWarnings, 'W', WARN_NUMERIC_SUSPECT, NULL, NULL );

         if( pOperand2 && pOperand2->cType != 'N' && pOperand2->cType != ' ' )
            GenWarning( _szCWarnings, 'W', WARN_NUMERIC_TYPE, sType2, NULL );
         else if( pOperand2 && pOperand2->cType == ' ' )
            GenWarning( _szCWarnings, 'W', WARN_NUMERIC_SUSPECT, NULL, NULL );

          /* compile time 2nd. operand has to be released */
         if( pOperand2 )
         {
            hb_xfree( ( void * ) pOperand2 );
         }

         /* compile time 1st. operand has to be released *but* result will be pushed and assumed numeric type */
         pStackValType = pOperand1;
         pStackValType->cType = 'N';
      }
      else if( byte == HB_P_PLUS || byte == HB_P_MINUS )
      {
         PSTACK_VAL_TYPE pOperand1 = NULL, pOperand2;
         char sType1[ 2 ], sType2[ 2 ], cType = ' ';

         /* 2nd. Operand (stack top)*/
         pOperand2 = pStackValType;

         /* skip back to the 1st. operand */
         if( pOperand2 )
         {
            pOperand1 = pOperand2->pPrev;
            sType2[ 0 ] = pOperand2->cType;
            sType2[ 1 ] = '\0';
         }
         else
            debug_msg( "\n***HB_P_PLUS / HB_P_MINUS Compile time stack overflow\n", NULL );

         if( pOperand1 )
         {
            sType1[ 0 ] = pOperand1->cType;
            sType1[ 1 ] = '\0';
         }
         else
            debug_msg( "\n***HB_P_PLUS / HB_P_MINUS2 Compile time stack overflow\n", NULL );

         if( pOperand1 && pOperand2 && pOperand1->cType != ' ' && pOperand2->cType != ' ' && pOperand1->cType != pOperand2->cType )
            GenWarning( _szCWarnings, 'W', WARN_OPERANDS_INCOMPATBLE, sType1, sType2 );
         else if( pOperand1 && pOperand2 && pOperand2->cType != ' ' && pOperand1->cType == ' ' )
            GenWarning( _szCWarnings, 'W', WARN_OPERAND_SUSPECT, sType2, NULL );
         else if( pOperand1 && pOperand2 && pOperand1->cType != ' ' && pOperand2->cType == ' ' )
            GenWarning( _szCWarnings, 'W', WARN_OPERAND_SUSPECT, sType1, NULL );
         else
            cType = pOperand1->cType;

          /* compile time 2nd. operand has to be released */
         if( pOperand2 )
         {
            hb_xfree( ( void * ) pOperand2 );
         }

         /* compile time 1st. operand has to be released *but* result will be pushed and type as calculated */
         /* Resetting */
         pStackValType = pOperand1;
         pStackValType->cType = cType;
      }
      else if( byte == HB_P_EQUAL || byte == HB_P_LESS ||  byte == HB_P_GREATER || byte == HB_P_INSTRING || byte == HB_P_LESSEQUAL || byte == HB_P_GREATEREQUAL || byte == HB_P_EXACTLYEQUAL || byte == HB_P_NOTEQUAL )
      {
         PSTACK_VAL_TYPE pOperand1 = NULL, pOperand2;
         char sType1[ 2 ], sType2[ 2 ];

         /* 2nd. Operand (stack top)*/
         pOperand2 = pStackValType;

         /* skip back to the 1st. operand */
         if( pOperand2 )
         {
            pOperand1 = pOperand2->pPrev;
            sType2[ 0 ] = pOperand2->cType;
            sType2[ 1 ] = '\0';
         }
         else
            debug_msg( "\n***HB_P_EQUAL pCode: %i Compile time stack overflow\n", byte );

         if( pOperand1 )
         {
            sType1[ 0 ] = pOperand1->cType;
            sType1[ 1 ] = '\0';
         }
         else
            debug_msg( "\n***HB_P_EQUAL2 pCode: %i Compile time stack overflow\n", byte );

         if( pOperand1 && pOperand2 && pOperand1->cType != ' ' && pOperand2->cType != ' ' && pOperand1->cType != pOperand2->cType )
            GenWarning( _szCWarnings, 'W', WARN_OPERANDS_INCOMPATBLE, sType1, sType2 );
         else if( pOperand1 && pOperand2 && pOperand2->cType != ' ' && pOperand1->cType == ' ' )
            GenWarning( _szCWarnings, 'W', WARN_OPERAND_SUSPECT, sType2, NULL );
         else if( pOperand1 && pOperand2 && pOperand1->cType != ' ' && pOperand2->cType == ' ' )
            GenWarning( _szCWarnings, 'W', WARN_OPERAND_SUSPECT, sType1, NULL );

          /* compile time 2nd. operand has to be released */
         if( pOperand2 )
         {
            hb_xfree( ( void * ) pOperand2 );
         }

         /* compile time 1st. operand has to be released *but* result will be pushed and of type logical */
         if( pOperand1 )
            pOperand1->cType = 'L';

         /* Resetting */
         pStackValType = pOperand1;
      }
      else if( byte == HB_P_NOT )
      {
         char sType[ 2 ];

         if( pStackValType )
         {
            sType[ 0 ] = pStackValType->cType;
            sType[ 1 ] = '\0';
         }
         else
            debug_msg( "\n***HB_P_NOT Compile time stack overflow\n", NULL );

         if( pStackValType && pStackValType->cType == ' ' )
            GenWarning( _szCWarnings, 'W', WARN_LOGICAL_SUSPECT, NULL, NULL );
         else if( pStackValType && pStackValType->cType != 'L' )
            GenWarning( _szCWarnings, 'W', WARN_LOGICAL_TYPE, sType, NULL );

         /* compile time 1st. operand has to be released *but* result will be pushed and assumed logical */
         if( pStackValType )
            pStackValType->cType = 'L';
      }
   }

   if( ! pFunc->pCode )   /* has been created the memory block to hold the pcode ? */
   {
      pFunc->pCode      = ( BYTE * ) hb_xgrab( PCODE_CHUNK );
      pFunc->lPCodeSize = PCODE_CHUNK;
      pFunc->lPCodePos  = 0;
   }
   else
      if( ( pFunc->lPCodeSize - pFunc->lPCodePos ) < 1 )
         pFunc->pCode = ( BYTE * ) hb_xrealloc( pFunc->pCode, pFunc->lPCodeSize += PCODE_CHUNK );

   pFunc->pCode[ pFunc->lPCodePos++ ] = byte;
}

void GenPCode3( BYTE byte1, BYTE byte2, BYTE byte3 )
{
   PFUNCTION pFunc = functions.pLast;   /* get the currently defined Clipper function */

   if( ! pFunc->pCode )   /* has been created the memory block to hold the pcode ? */
   {
      pFunc->pCode      = ( BYTE * ) hb_xgrab( PCODE_CHUNK );
      pFunc->lPCodeSize = PCODE_CHUNK;
      pFunc->lPCodePos  = 0;
   }
   else
      if( ( pFunc->lPCodeSize - pFunc->lPCodePos ) < 3 )
         pFunc->pCode = ( BYTE * ) hb_xrealloc( pFunc->pCode, pFunc->lPCodeSize += PCODE_CHUNK );

   pFunc->pCode[ pFunc->lPCodePos++ ] = byte1;
   pFunc->pCode[ pFunc->lPCodePos++ ] = byte2;
   pFunc->pCode[ pFunc->lPCodePos++ ] = byte3;
}

void GenPCodeN( BYTE * pBuffer, ULONG ulSize )
{
   PFUNCTION pFunc = functions.pLast;   /* get the currently defined Clipper function */

   if( ! pFunc->pCode )   /* has been created the memory block to hold the pcode ? */
   {
      pFunc->lPCodeSize = ( ( ulSize / PCODE_CHUNK ) + 1 ) * PCODE_CHUNK;
      pFunc->pCode      = ( BYTE * ) hb_xgrab( pFunc->lPCodeSize );
      pFunc->lPCodePos  = 0;
   }
   else if( pFunc->lPCodePos + ulSize > pFunc->lPCodeSize )
   {
      /* not enough free space in pcode buffer - increase it */
      pFunc->lPCodeSize += ( ( ( ulSize / PCODE_CHUNK ) + 1 ) * PCODE_CHUNK );
      pFunc->pCode = ( BYTE * ) hb_xrealloc( pFunc->pCode, pFunc->lPCodeSize );
   }

   memcpy( pFunc->pCode + pFunc->lPCodePos, pBuffer, ulSize );
   pFunc->lPCodePos += ulSize;
}

char * SetData( char * szMsg ) /* generates an underscore-symbol name for a data assignment */
{
   char * szResult = ( char * ) hb_xgrab( strlen( szMsg ) + 2 );

   strcpy( szResult, "_" );
   strcat( szResult, szMsg );

   return szResult;
}

/* Generate the opcode to open BEGIN/END sequence
 * This code is simmilar to JUMP opcode - the offset will be filled with
 * - either the address of HB_P_SEQEND opcode if there is no RECOVER clause
 * - or the address of RECOVER code
 */
ULONG SequenceBegin( void )
{
   GenPCode3( HB_P_SEQBEGIN, 0, 0 );

   return functions.pLast->lPCodePos - 2;
}

/* Generate the opcode to close BEGIN/END sequence
 * This code is simmilar to JUMP opcode - the offset will be filled with
 * the address of first line after END SEQUENCE
 * This opcode will be executed if recover code was not requested (as the
 * last statement in code beetwen BEGIN ... RECOVER) or if BREAK was requested
 * and there was no matching RECOVER clause.
 */
ULONG SequenceEnd( void )
{
   GenPCode3( HB_P_SEQEND, 0, 0 );

   return functions.pLast->lPCodePos - 2;
}

/* Remove unnecessary opcodes in case there were no executable statements
 * beetwen BEGIN and RECOVER sequence
 */
void SequenceFinish( ULONG ulStartPos, int bUsualStmts )
{
   if( ! _bDebugInfo ) /* only if no debugger info is required */
   {
      if( ! bUsualStmts )
      {
         functions.pLast->lPCodePos = ulStartPos - 1; /* remove also HB_P_SEQBEGIN */
         _ulLastLinePos = ulStartPos - 4;
      }
   }
}


/*
 * Start a new fake-function that will hold pcodes for a codeblock
*/
void CodeBlockStart()
{
   PFUNCTION pFunc = FunctionNew( NULL, FS_STATIC );

   pFunc->pOwner       = functions.pLast;
   pFunc->iStaticsBase = functions.pLast->iStaticsBase;

   functions.pLast = pFunc;
   LineDebug();
}

void CodeBlockEnd()
{
   PFUNCTION pCodeblock;   /* pointer to the current codeblock */
   PFUNCTION pFunc;        /* pointer to a function that owns a codeblock */
   WORD wSize;
   WORD wLocals = 0;   /* number of referenced local variables */
   WORD wPos;
   PVAR pVar, pFree;

   pCodeblock = functions.pLast;

   /* return to pcode buffer of function/codeblock in which the current
    * codeblock was defined
    */
   functions.pLast = pCodeblock->pOwner;

   /* find the function that owns the codeblock */
   pFunc = pCodeblock->pOwner;
   while( pFunc->pOwner )
      pFunc = pFunc->pOwner;
   pFunc->bFlags |= ( pCodeblock->bFlags & FUN_USES_STATICS );

   /* generate a proper codeblock frame with a codeblock size and with
    * a number of expected parameters
    */
   /*QUESTION: would be 64kB enough for a codeblock size?
    * we are assuming now a WORD for a size of codeblock
    */

   /* Count the number of referenced local variables */
   pVar = pCodeblock->pStatics;
   while( pVar )
   {
      pVar = pVar->pNext;
      ++wLocals;
   }

   /*NOTE:  8 = HB_P_PUSHBLOCK + WORD( size ) + WORD( wParams ) + WORD( wLocals ) + _ENDBLOCK */
   wSize = ( WORD ) pCodeblock->lPCodePos + 8 + wLocals * 2;

   GenPCode3( HB_P_PUSHBLOCK, LOBYTE( wSize ), HIBYTE( wSize ) );
   GenPCode1( LOBYTE( pCodeblock->wParamCount ) );
   GenPCode1( HIBYTE( pCodeblock->wParamCount ) );
   GenPCode1( LOBYTE( wLocals ) );
   GenPCode1( HIBYTE( wLocals ) );

   /* generate the table of referenced local variables */
   pVar = pCodeblock->pStatics;
   while( wLocals-- )
   {
      wPos = GetVarPos( pFunc->pLocals, pVar->szName );
      GenPCode1( LOBYTE( wPos ) );
      GenPCode1( HIBYTE( wPos ) );

      pFree = pVar;
      hb_xfree( ( void * ) pFree->szName );
      pVar = pVar->pNext;
      hb_xfree( ( void * ) pFree );
   }

   GenPCodeN( pCodeblock->pCode, pCodeblock->lPCodePos );
   GenPCode1( HB_P_ENDBLOCK ); /* finish the codeblock */

   /* this fake-function is no longer needed */
   hb_xfree( ( void * ) pCodeblock->pCode );
   pVar = pCodeblock->pLocals;
   while( pVar )
   {
      if( _bWarnings && pFunc->szName && pVar->szName && ! pVar->iUsed )
         GenWarning( _szCWarnings, 'W', WARN_BLOCKVAR_NOT_USED, pVar->szName, pFunc->szName );

      /* free used variables */
      pFree = pVar;
      hb_xfree( ( void * ) pFree->szName );
      pVar = pVar->pNext;
      hb_xfree( ( void * ) pFree );
   }
   hb_xfree( ( void * ) pCodeblock );

   if( _bWarnings )
   {
      if( pStackValType )
         /* reusing the place holder of the result value */
         pStackValType->cType = 'B';
      else
         debug_msg( "\n***CodeBlockEnd() Compile time stack overflow\n", NULL );
   }
}

/* Set the name of an alias for the list of previously declared FIELDs
 *
 * szAlias -> name of the alias
 * iField  -> position of the first FIELD name to change
 */
void FieldsSetAlias( char * szAlias, int iField )
{
   PVAR pVar;

   pVar = functions.pLast->pFields;
   while( iField-- && pVar )
      pVar = pVar->pNext;

   while( pVar )
   {
      pVar->szAlias = szAlias;
      pVar = pVar->pNext;
   }
}

/* This functions counts the number of FIELD declaration in a function
 * We will required this information in FieldsSetAlias function
 */
int FieldsCount()
{
   int iFields = 0;
   PVAR pVar = functions.pLast->pFields;

   while( pVar )
   {
      ++iFields;
      pVar = pVar->pNext;
   }

   return iFields;
}

/*
 * Start of definition of static variable
 * We are using here the special function _pInitFunc which will store
 * pcode needed to initialize all static variables declared in PRG module.
 * pOwner member will point to a function where the static variable is
 * declared:
 * TODO: support for static variables in codeblock
 */
void StaticDefStart( void )
{
   iVarScope = VS_STATIC;
   Line();

   functions.pLast->bFlags |= FUN_USES_STATICS;
   if( ! _pInitFunc )
   {
      _pInitFunc = FunctionNew( yy_strdup("(_INITSTATICS)"), FS_INIT );
      _pInitFunc->pOwner = functions.pLast;
      _pInitFunc->bFlags = FUN_USES_STATICS | FUN_PROCEDURE;
      _pInitFunc->cScope = FS_INIT | FS_EXIT;
      functions.pLast = _pInitFunc;
      PushInteger( 1 );   /* the number of static variables is unknown now */
      GenPCode3( HB_P_STATICS, 0, 0 );
      GenPCode3( HB_P_SFRAME, 0, 0 );     /* frame for statics variables */
   }
   else
   {
      _pInitFunc->pOwner = functions.pLast;
      functions.pLast = _pInitFunc;
   }
}

/*
 * End of definition of static variable
 * Return to previously pcoded function.
 */
void StaticDefEnd( int iCount )
{
   functions.pLast = _pInitFunc->pOwner;
   _pInitFunc->pOwner = NULL;
   _iStatics += iCount;
   iVarScope = VS_LOCAL;

   if( _bWarnings )
   {
      PSTACK_VAL_TYPE pFree;

      if( pStackValType )
      {
         pFree = pStackValType;
         debug_msg( "\n***---%i in StaticeDefEnd()\n", _iStatics );

         pStackValType = pStackValType->pPrev;
         hb_xfree( ( void * ) pFree );
      }
      else
         debug_msg( "\n***StaticDefEnd() Compile time stack overflow\n", NULL );
   }
}

/*
 * This function checks if we are initializing a static variable.
 * It should be called only in case when the parser have recognized any
 * function or method invocation.
 */
void StaticAssign( void )
{
   if( iVarScope == VS_STATIC && functions.pLast->szName )
      /* function call is allowed if it is inside a codeblock
       */
      _pInitFunc->bFlags |= FUN_ILLEGAL_INIT;
}

/*
 * This function stores the position in pcode buffer where the FOR/WHILE
 * loop starts. It will be used to fix any LOOP/EXIT statements
 */
static void LoopStart( void )
{
   PTR_LOOPEXIT pLoop = ( PTR_LOOPEXIT ) hb_xgrab( sizeof( LOOPEXIT ) );

   if( pLoops )
   {
      PTR_LOOPEXIT pLast = pLoops;

      while( pLast->pNext )
         pLast = pLast->pNext;
      pLast->pNext = pLoop;
   }
   else
      pLoops = pLoop;

   pLoop->pNext       = NULL;
   pLoop->pExitList   = NULL;
   pLoop->pLoopList   = NULL;
   pLoop->ulOffset = functions.pLast->lPCodePos;  /* store the start position */
   pLoop->iLine   = iLine;
}

/*
 * Stores the position of LOOP statement to fix it later at the end of loop
 */
static void LoopLoop( void )
{
   PTR_LOOPEXIT pLast, pLoop;

   if( _wSeqCounter && _wSeqCounter >= _wWhileCounter )
   {
      /* Attempt to LOOP from BEGIN/END sequence
       * Notice that LOOP is allowed in RECOVER code.
       */
      GenError( _szCErrors, 'E', ERR_EXIT_IN_SEQUENCE, "LOOP", NULL );
   }

   pLoop = ( PTR_LOOPEXIT ) hb_xgrab( sizeof( LOOPEXIT ) );

   pLoop->pLoopList = NULL;
   pLoop->ulOffset = functions.pLast->lPCodePos;  /* store the position to fix */

   pLast = pLoops;
   while( pLast->pNext )
      pLast = pLast->pNext;

   while( pLast->pLoopList )
      pLast = pLast->pLoopList;

   pLast->pLoopList = pLoop;

   Jump( 0 );
}

/*
 * Stores the position of EXIT statement to fix it later at the end of loop
 */
static void LoopExit( void )
{
   PTR_LOOPEXIT pLast, pLoop;

   if( _wSeqCounter && _wSeqCounter >= _wWhileCounter )
   {
      /* Attempt to EXIT from BEGIN/END sequence
       * Notice that EXIT is allowed in RECOVER code.
       */
      GenError( _szCErrors, 'E', ERR_EXIT_IN_SEQUENCE, "EXIT", NULL );
   }

   pLoop = ( PTR_LOOPEXIT ) hb_xgrab( sizeof( LOOPEXIT ) );

   pLoop->pExitList = NULL;
   pLoop->ulOffset = functions.pLast->lPCodePos;  /* store the position to fix */

   pLast = pLoops;
   while( pLast->pNext )
      pLast = pLast->pNext;

   while( pLast->pExitList )
      pLast = pLast->pExitList;

   pLast->pExitList = pLoop;

   Jump( 0 );
}

/*
 * Fixes the LOOP statement
 */
static void LoopHere( void )
{
   PTR_LOOPEXIT pLoop = pLoops, pFree;

   while( pLoop->pNext )
      pLoop = pLoop->pNext;

   pLoop = pLoop->pLoopList;
   while( pLoop )
   {
      JumpHere( pLoop->ulOffset + 1 );
      pFree = pLoop;
      pLoop = pLoop->pLoopList;
      hb_xfree( ( void * ) pFree );
   }
}

/*
 * Fixes the EXIT statements and releases memory allocated for current loop
 */
static void LoopEnd( void )
{
   PTR_LOOPEXIT pExit, pLoop = pLoops, pLast = pLoops, pFree;

   while( pLoop->pNext )
   {
      pLast = pLoop;
      pLoop = pLoop->pNext;
   }

   pExit = pLoop->pExitList;
   while( pExit )
   {
      JumpHere( pExit->ulOffset + 1 );
      pFree = pExit;
      pExit = pExit->pExitList;
      hb_xfree( ( void * ) pFree );
   }

   pLast->pNext = NULL;
   if( pLoop == pLoops )
      pLoops = NULL;
   hb_xfree( ( void * ) pLoop );
}

#define IS_PATH_SEP( c ) ( strchr( OS_PATH_DELIMITER_LIST, ( c ) ) != NULL )

/* Split given filename into path, name and extension */
PHB_FNAME hb_fsFNameSplit( char * szFileName )
{
   PHB_FNAME pFileName = ( PHB_FNAME ) hb_xgrab( sizeof( HB_FNAME ) );

   int iLen = strlen( szFileName );
   int iSlashPos;
   int iDotPos;
   int iPos;

   pFileName->szPath =
   pFileName->szName =
   pFileName->szExtension = NULL;

   iSlashPos = iLen - 1;
   iPos = 0;

   while( iSlashPos >= 0 && !IS_PATH_SEP( szFileName[ iSlashPos ] ) )
      --iSlashPos;

   if( iSlashPos == 0 )
   {
      /* root path -> \filename */
      pFileName->szBuffer[ 0 ] = OS_PATH_DELIMITER;
      pFileName->szBuffer[ 1 ] = '\0';
      pFileName->szPath = pFileName->szBuffer;
      iPos = 2; /* first free position after the slash */
   }
   else if( iSlashPos > 0 )
   {
      /* If we are after a drive letter let's keep the following backslash */
      if( IS_PATH_SEP( ':' ) &&
         ( szFileName[ iSlashPos ] == ':' || szFileName[ iSlashPos - 1 ] == ':' ) )
      {
         /* path with separator -> d:\path\filename or d:path\filename */
         memcpy( pFileName->szBuffer, szFileName, iSlashPos + 1 );
         pFileName->szBuffer[ iSlashPos + 1 ] = '\0';
         iPos = iSlashPos + 2; /* first free position after the slash */
      }
      else
      {
         /* path with separator -> path\filename */
         memcpy( pFileName->szBuffer, szFileName, iSlashPos );
         pFileName->szBuffer[ iSlashPos ] = '\0';
         iPos = iSlashPos + 1; /* first free position after the slash */
      }

      pFileName->szPath = pFileName->szBuffer;
   }

   iDotPos = iLen - 1;
   while( iDotPos > iSlashPos && szFileName[ iDotPos ] != '.' )
      --iDotPos;

   if( ( iDotPos - iSlashPos ) > 1 )
   {
      /* the dot was found
       * and there is at least one character between a slash and a dot
       */
      if( iDotPos == iLen - 1 )
      {
         /* the dot is the last character - use it as extension name */
         pFileName->szExtension = pFileName->szBuffer + iPos;
         pFileName->szBuffer[ iPos++ ] = '.';
         pFileName->szBuffer[ iPos++ ] = '\0';
      }
      else
      {
         pFileName->szExtension = pFileName->szBuffer + iPos;
         /* copy rest of the string with terminating ZERO character */
         memcpy( pFileName->szExtension, szFileName + iDotPos + 1, iLen - iDotPos );
         iPos += iLen - iDotPos;
      }
   }
   else
      /* there is no dot in the filename or it is  '.filename' */
      iDotPos = iLen;

   if( ( iDotPos - iSlashPos - 1 ) > 0 )
   {
      pFileName->szName = pFileName->szBuffer + iPos;
      memcpy( pFileName->szName, szFileName + iSlashPos + 1, iDotPos - iSlashPos - 1 );
      pFileName->szName[ iDotPos - iSlashPos - 1 ] = '\0';
   }

/* DEBUG
   printf( "\nFilename: %s\n", szFileName );
   printf( "\n  szPath: %s\n", pFileName->szPath );
   printf( "\n  szName: %s\n", pFileName->szName );
   printf( "\n   szExt: %s\n", pFileName->szExtension );
*/

   return pFileName;
}

/* This function joins path, name and extension into a string with a filename */
char * hb_fsFNameMerge( char * szFileName, PHB_FNAME pFileName )
{
   if( pFileName->szPath && pFileName->szPath[ 0 ] )
   {
      /* we have not empty path specified */
      int iLen = strlen( pFileName->szPath );

      strcpy( szFileName, pFileName->szPath );

      /* if the path is a root directory then we don't need to add path separator */
      if( !( IS_PATH_SEP( pFileName->szPath[ 0 ] ) && pFileName->szPath[ 0 ] == '\0' ) )
      {
         /* add the path separator only in cases:
          *  when a name doesn't start with it
          *  when the path doesn't end with it
          */
         if( !( IS_PATH_SEP( pFileName->szName[ 0 ] ) || IS_PATH_SEP( pFileName->szPath[ iLen-1 ] ) ) )
         {
            szFileName[ iLen++ ] = OS_PATH_DELIMITER;
            szFileName[ iLen ] = '\0';
         }
      }
      if( pFileName->szName )
         strcpy( szFileName + iLen, pFileName->szName );
   }
   else
   {
      if( pFileName->szName )
         strcpy( szFileName, pFileName->szName );
   }

   if( pFileName->szExtension )
   {
      int iLen = strlen( szFileName );

      if( !( pFileName->szExtension[ 0 ] == '.' || szFileName[ iLen - 1 ] == '.') )
      {
         /* add extension separator only when extansion doesn't contain it */
         szFileName[ iLen++ ] = '.';
         szFileName[ iLen ] = '\0';
      }
      strcpy( szFileName + iLen, pFileName->szExtension );
   }

/* DEBUG
   printf( "\nMERGE:\n" );
   printf( "\n  szPath: %s\n", pFileName->szPath );
   printf( "\n  szName: %s\n", pFileName->szName );
   printf( "\n   szExt: %s\n", pFileName->szExtension );
   printf( "\nFilename result: %s\n", szFileName );
*/

   return szFileName;
}

void * hb_xgrab( ULONG ulSize )         /* allocates fixed memory, exits on failure */
{
   void * pMem = malloc( ulSize );

   if( ! pMem )
      GenError( _szCErrors, 'E', ERR_MEMALLOC, NULL, NULL );

   return pMem;
}

void * hb_xrealloc( void * pMem, ULONG ulSize )       /* reallocates memory */
{
   void * pResult = realloc( pMem, ulSize );

   if( ! pResult )
      GenError( _szCErrors, 'E', ERR_MEMREALLOC, NULL, NULL );

   return pResult;
}

void hb_xfree( void * pMem )            /* frees fixed memory */
{
   if( pMem )
      free( pMem );
   else
      GenError( _szCErrors, 'E', ERR_MEMFREE, NULL, NULL );
}

char * yy_strupr( char * p )
{
   char * p1;

   for( p1 = p; * p1; p1++ )
      * p1 = toupper( * p1 );

   return p;
}

char * yy_strdup( char * p )
{
   char * pDup;
   int iLen;

   iLen = strlen( p ) + 1;
   pDup = ( char * ) hb_xgrab( iLen );
   memcpy( pDup, p, iLen );

   return pDup;
}

/* checks if passed string is a reserved function name
 */
static char * reserved_name( char * szName )
{
   WORD wNum = 0;
   int iFound = 1;

   while( wNum < RESERVED_FUNCTIONS && iFound )
   {
      /* Compare first 4 characters
      * If they are the same then compare the whole name
      * SECO() is not allowed because of Clipper function SECONDS()
      * however SECO32() is a valid name.
      */
      iFound = strncmp( szName, _szReservedFun[ wNum ], 4 );
      if( iFound == 0 )
         iFound = strncmp( szName, _szReservedFun[ wNum ], strlen( szName ) );
      ++wNum;
   }
   if( iFound )
      return NULL;
   else
      return (char *) _szReservedFun[ wNum - 1 ];
}

/* NOTE: iMinParam = -1, means no checking */
/*       iMaxParam = -1, means no upper limit */

typedef struct
{
   char * cFuncName;                /* function name              */
   int    iMinParam;                /* min no of parms it needs   */
   int    iMaxParam;                /* max no of parms need       */
} FUNCINFO, * PFUNCINFO;

static FUNCINFO _StdFun[] =
{
   { "AADD"      , 2,  2 },
   { "ABS"       , 1,  1 },
   { "ASC"       , 1,  1 },
   { "AT"        , 2,  2 },
   { "BOF"       , 0,  0 },
   { "BREAK"     , 0,  1 },
   { "CDOW"      , 1,  1 },
   { "CHR"       , 1,  1 },
   { "CMONTH"    , 1,  1 },
   { "COL"       , 0,  0 },
   { "CTOD"      , 1,  1 },
   { "DATE"      , 0,  0 },
   { "DAY"       , 1,  1 },
   { "DELETED"   , 0,  0 },
   { "DEVPOS"    , 2,  2 },
   { "DOW"       , 1,  1 },
   { "DTOC"      , 1,  1 },
   { "DTOS"      , 1,  1 },
   { "EMPTY"     , 1,  1 },
   { "EOF"       , 0,  0 },
   { "EVAL"      , 1, -1 },
   { "EXP"       , 1,  1 },
   { "FCOUNT"    , 0,  0 },
   { "FIELDNAME" , 1,  1 },
   { "FILE"      , 1,  1 },
   { "FLOCK"     , 0,  0 },
   { "FOUND"     , 0,  0 },
   { "INKEY"     , 0,  2 },
   { "INT"       , 1,  1 },
   { "LASTREC"   , 0,  0 },
   { "LEFT"      , 2,  2 },
   { "LEN"       , 1,  1 },
   { "LOCK"      , 0,  0 },
   { "LOG"       , 1,  1 },
   { "LOWER"     , 1,  1 },
   { "LTRIM"     , 1,  1 },
   { "MAX"       , 2,  2 },
   { "MIN"       , 2,  2 },
   { "MONTH"     , 1,  1 },
   { "PCOL"      , 0,  0 },
   { "PCOUNT"    , 0,  0 },
   { "PROW"      , 0,  0 },
   { "RECCOUNT"  , 0,  0 },
   { "RECNO"     , 0,  0 },
   { "REPLICATE" , 2,  2 },
   { "RLOCK"     , 0,  0 },
   { "ROUND"     , 2,  2 },
   { "ROW"       , 0,  0 },
   { "RTRIM"     , 1,  2 }, /* Second parameter is a Harbour extension */
   { "SECONDS"   , 0,  0 },
   { "SELECT"    , 0,  1 },
   { "SETPOS"    , 2,  2 },
   { "SETPOSBS"  , 0,  0 },
   { "SPACE"     , 1,  1 },
   { "SQRT"      , 1,  1 },
   { "STR"       , 1,  3 },
   { "SUBSTR"    , 2,  3 },
   { "TIME"      , 0,  0 },
   { "TRANSFORM" , 2,  2 },
   { "TRIM"      , 1,  2 }, /* Second parameter is a Harbour extension */
   { "TYPE"      , 1,  1 },
   { "UPPER"     , 1,  1 },
   { "VAL"       , 1,  1 },
   { "VALTYPE"   , 1,  1 },
   { "WORD"      , 1,  1 },
   { "YEAR"      , 1,  1 },
   { 0           , 0,  0 }
};

void CheckArgs( char * szFuncCall, int iArgs )
{
   FUNCINFO * f = _StdFun;
   int i = 0;
   int iPos = -1;
   int iCmp;

   while( f[ i ].cFuncName )
   {
      iCmp = strncmp( szFuncCall, f[ i ].cFuncName, 4 );
      if( iCmp == 0 )
         iCmp = strncmp( szFuncCall, f[ i ].cFuncName, strlen( szFuncCall ) );
      if( iCmp == 0 )
      {
         iPos = i;
         break;
      }
      else
         ++i;
   }

   if( iPos >= 0 && ( f[ iPos ].iMinParam != -1 ) )
   {
      if( iArgs < f[ iPos ].iMinParam || ( f[ iPos ].iMaxParam != -1 && iArgs > f[ iPos ].iMaxParam ) )
      {
         char szMsg[ 40 ];

         if( f[ iPos ].iMaxParam == -1 )
            sprintf( szMsg, "\nPassed: %i, expected: at least %i", iArgs, f[ iPos ].iMinParam );
         else if( f[ iPos ].iMinParam == f[ iPos ].iMaxParam )
            sprintf( szMsg, "\nPassed: %i, expected: %i", iArgs, f[ iPos ].iMinParam );
         else
            sprintf( szMsg, "\nPassed: %i, expected: %i - %i", iArgs, f[ iPos ].iMinParam, f[ iPos ].iMaxParam );

         GenError( _szCErrors, 'E', ERR_CHECKING_ARGS, szFuncCall, szMsg );

         /* Clipper way */
         /* GenError( _szCErrors, 'E', ERR_CHECKING_ARGS, szFuncCall, NULL ); */
      }
   }
}

/* NOTE: Making the date and time info to fit into 32 bits can only be done
         in a "lossy" way, in practice that means it's not possible to unpack
         the exact date/time info from the resulting ULONG. Since the year
         is only stored in 6 bits, 1980 will result in the same bit pattern
         as 2044. The purpose of this value is only used to *differenciate*
         between the dates ( the exact dates are not significant ), so this can
         be used here without problems. */

/* 76543210765432107654321076543210
   |.......|.......|.......|.......
   |____|                               Year    6 bits
         |__|                           Month   4 bits
             |___|                      Day     5 bits
                  |___|                 Hour    5 bits
                       |____|           Minute  6 bits
                             |____|     Second  6 bits */

static ULONG PackDateTime( void )
{
   BYTE szString[ 4 ];
   BYTE nValue;

   time_t t;
   struct tm * oTime;

   time( &t );
   oTime = localtime( &t );

   nValue = ( BYTE ) ( ( ( oTime->tm_year + 1900 ) - 1980 ) & ( 2 ^ 6 ) ) ; /* 6 bits */
   szString[ 0 ]  = nValue << 2;
   nValue = ( BYTE ) ( oTime->tm_mon + 1 ); /* 4 bits */
   szString[ 0 ] |= nValue >> 2;
   szString[ 1 ]  = nValue << 6;
   nValue = ( BYTE ) ( oTime->tm_mday ); /* 5 bits */
   szString[ 1 ] |= nValue << 1;

   nValue = ( BYTE ) oTime->tm_hour; /* 5 bits */
   szString[ 1 ]  = nValue >> 4;
   szString[ 2 ]  = nValue << 4;
   nValue = ( BYTE ) oTime->tm_min; /* 6 bits */
   szString[ 2 ] |= nValue >> 2;
   szString[ 3 ]  = nValue << 6;
   nValue = ( BYTE ) oTime->tm_sec; /* 6 bits */
   szString[ 3 ] |= nValue;

   return MKLONG( szString[ 3 ], szString[ 2 ], szString[ 1 ], szString[ 0 ] );
}

