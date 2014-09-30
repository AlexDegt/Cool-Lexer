/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

unsigned int comment = 0;
unsigned int string_buf_left;

/*
 *  Add Your own definitions here
 */

%}

/*
 * Define names for regular expressions here.
 */

CLASS           [cC][lL][aA][sS][sS]
DARROW          =>
DIGIT           [0-9]
ELSE            [eE][lL][sS][eE]
FALSE           f[aA][lL][sS][eE]
FI              [fF][iI]
IF              [iI][fF]
IN              [iI][nN]
INHERITS        [iI][nN][hH][eE][rR][iI][tT][sS]
ISVOID          [iI][sS][vV][oO][iI][dD]
LET             [lL][eE][tT]
LOOP            [lL][oO][oO][pP]
POOL            [pP][oO][oO][lL]
THEN            [tT][hH][eE][nN]
WHILE           [wW][hH][iI][lL][eE]
CASE            [cC][aA][sS][eE]
ESAC            [eE][sS][aA][cC]
NEW             [nN][eE][wW]
OF              [oO][fF]
NOT             [nN][oO][tT]
TRUE            t[rR][uU][eE]
OBJECTID        [a-z][_a-zA-Z]*
TYPEID          [A-Z][_a-zA-Z]*
NEWLINE         [\n\r\v\f]
NOTNEWLINE      [^\n\r\v\f]
NOTCOMMENT      [^\n\r\v\f"(*""*)"]
NOTSTRING       [^\n\r\v\f\0\"]
WHITESPACE      [ \t]+
LE              <=
NULLCH          [\0]
BACKSLASH       [\\]

LINE_COMMENT    "--"
START_COMMENT   "(*"
END_COMMENT     "*)"

QUOTES          \"

%Start COMMENT
%Start STRING

%%

 /*
  *  Nested comments
  */


 /*
  *  The multiple-character operators.
  */
   /* Priorities:
    *  New line
    *  Comments
    *  String
    *  Whitespace
    *  Keywords
    *  Identifiers
    *  Integers
    *  Error
    */
{NEWLINE}               { curr_lineno++; }

{START_COMMENT}                        { comment++; BEGIN(COMMENT); }
<COMMENT><<EOF>>                       { yylval.error_msg = "EOF in comment"; return (ERROR); }
<COMMENT>{NOTCOMMENT}*{START_COMMENT}  { comment++; }
<COMMENT>{NOTCOMMENT}*{END_COMMENT}    { comment--; if (comment == 0) BEGIN(INITIAL); }
<COMMENT>{NOTCOMMENT}*                 ;
<INITIAL>{END_COMMENT}                 { yylval.error_msg = "Unmatched *)"; return (ERROR); }
{LINE_COMMENT}{NOTNEWLINE}*            ;

{QUOTES}                       { BEGIN(STRING); string_buf_ptr = string_buf; string_buf_left = MAX_STR_CONST; }
<STRING><<EOF>>                { yylval.error_msg = "EOF in string constant"; return (ERROR); }
<STRING>{NOTSTRING}*{NULLCH}   { yylval.error_msg = "String contains null character"; return (ERROR); }
<STRING>{NOTSTRING}*{QUOTES}   { 
                                    if (strlen(yytext) -1 < string_buf_left) {
                                         strncpy(string_buf_ptr, yytext, strlen(yytext) - 1);
                                         string_buf_ptr += strlen(yytext) - 1;
                                         string_buf_left -= strlen(yytext) - 1;
                                         yylval.symbol = stringtable.add_string(string_buf, string_buf_ptr - string_buf);
                                         BEGIN(INITIAL);
                                         return (STR_CONST);
                                      } else {
                                          yylval.error_msg = "String constant too long";
                                          return (ERROR);
                                      }
                               }
<STRING>{NOTSTRING}*           { 
                                     if (strlen(yytext) < string_buf_left) {
                                           strncpy(string_buf_ptr, yytext, strlen(yytext));
                                          string_buf_ptr += strlen(yytext);
                                           string_buf_left -= strlen(yytext);
                                       } else {
                                          yylval.error_msg = "String constant too long";
                                          return (ERROR);
                                       }
                               }

{WHITESPACE}            ;

{TRUE}                  { yylval.boolean = true; return (BOOL_CONST); }
{FALSE}                 { yylval.boolean = false; return (BOOL_CONST); }

{CLASS}                 { return (CLASS); }
{ELSE}                  { return (ELSE); }
{FI}                    { return (FI); }
{IF}                    { return (IF); }
{IN}                    { return (IN); }
{INHERITS}              { return (INHERITS); }
{ISVOID}                { return (ISVOID); }
{LET}                   { return (LET); }
{LOOP}                  { return (LOOP); }
{POOL}                  { return (POOL); }
{THEN}                  { return (THEN); }
{WHILE}                 { return (WHILE); }
{CASE}                  { return (CASE); }
{ESAC}                  { return (ESAC); }
{NEW}                   { return (NEW); }
{OF}                    { return (OF); }
{NOT}                   { return (NOT); }
{DARROW}		{ return (DARROW); }
{LE}                    { return (LE); }

{TYPEID}                { yylval.symbol = stringtable.add_string(yytext); return (TYPEID); }
{OBJECTID}              { yylval.symbol = stringtable.add_string(yytext); return (OBJECTID); }
{DIGIT}+                { yylval.symbol = stringtable.add_string(yytext); return (INT_CONST); }

";"                     { return int(';'); }
","                     { return int(','); }
":"                     { return int(':'); }
"{"                     { return int('{'); }
"}"                     { return int('}'); }
"+"                     { return int('+'); }
"-"                     { return int('-'); }
"*"                     { return int('*'); }
"/"                     { return int('/'); }
"["                     { return int('['); }
"]"                     { return int(']'); }
"<"                     { return int('<'); }
">"                     { return int('>'); }
"="                     { return int('='); }
"~"                     { return int('~'); }
"."                     { return int('.'); }
"@"                     { return int('@'); }
"("                     { return int('('); }
")"                     { return int(')'); }
.                       { return int(yytext[0]); }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for
  *  \n \t \b \f, the result is c.
  *
  */


%%
