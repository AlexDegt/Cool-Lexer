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
bool string_error;

int str_write(char *str, unsigned int len) {
  if (len < string_buf_left) {
    strncpy(string_buf_ptr, str, len);
    string_buf_ptr += len;
    string_buf_left -= len;
    return 0;
  } else {
    string_error = true;
    yylval.error_msg = "String constant too long";
    return -1;
  }
}

int null_character_err() {
  yylval.error_msg = "String contains null character";
  string_error = true;
  return -1;
}

char * backslash_common() {
  char *c = &yytext[1];
  if (*c == '\n') {
    curr_lineno++;
  }
  return c;
}

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
OBJECTID        [a-z][_a-zA-Z0-9]*
TYPEID          [A-Z][_a-zA-Z0-9]*
NEWLINE         [\n]
NOTNEWLINE      [^\n]
NOTCOMMENT      [^\n*(\\]
NOTSTRING       [^\n\0\\\"]
WHITESPACE      [ \t\r\f\v]+
LE              <=
ASSIGN          <-
NULLCH          [\0]
BACKSLASH       [\\]
STAR            [*]
NOTSTAR         [^*]
LEFTPAREN       [(]
NOTLEFTPAREN    [^(]
RIGHTPAREN      [)]
NOTRIGHTPAREN   [^)]

LINE_COMMENT    "--"
START_COMMENT   "(*"
END_COMMENT     "*)"

QUOTES          \"

%x COMMENT
%x STRING

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
<INITIAL,COMMENT>{NEWLINE} {
    curr_lineno++;
}

{START_COMMENT} {
  comment++;
  BEGIN(COMMENT);
}

<COMMENT><<EOF>> {
  yylval.error_msg = "EOF in comment";
  BEGIN(INITIAL);
  return (ERROR);
}

<COMMENT>{STAR}/{NOTRIGHTPAREN}    ;
<COMMENT>{LEFTPAREN}/{NOTSTAR}     ;
<COMMENT>{NOTCOMMENT}*             ;

<COMMENT>{BACKSLASH}(.|{NEWLINE}) {
  backslash_common();
};
<COMMENT>{BACKSLASH}               ;

<COMMENT>{START_COMMENT} {
  comment++;
}

<COMMENT>{END_COMMENT} {
  comment--;
  if (comment == 0) {
    BEGIN(INITIAL);
  }
}

<INITIAL>{END_COMMENT} {
  yylval.error_msg = "Unmatched *)";
  return (ERROR);
}

<INITIAL>{LINE_COMMENT}{NOTNEWLINE}*  ;

<INITIAL>{QUOTES} {
  BEGIN(STRING);
  string_buf_ptr = string_buf;
  string_buf_left = MAX_STR_CONST;
  string_error = false;
}

<STRING><<EOF>> {
  yylval.error_msg = "EOF in string constant";
  BEGIN(INITIAL);
  return ERROR;
}

<STRING>{NOTSTRING}* {
  int rc = str_write(yytext, strlen(yytext));
  if (rc != 0) {
    return (ERROR);
  }
}
<STRING>{NULLCH} {
  null_character_err();
  return (ERROR);
}

<STRING>{NEWLINE} {
  BEGIN(INITIAL);
  curr_lineno++;
  if (!string_error) {
    yylval.error_msg = "Unterminated string constant";
    return (ERROR);
  }
}
<STRING>{BACKSLASH}(.|{NEWLINE}) {
  char *c = backslash_common();
  int rc;

  switch (*c) {
    case 'n':
      rc = str_write("\n", 1);
      break;
    case 'b':
      rc = str_write("\b", 1);
      break;
    case 't':
      rc = str_write("\t", 1);
      break;
    case 'f':
      rc = str_write("\f", 1);
      break;
    case '\0':
      rc = null_character_err();
      break;
    default:
      rc = str_write(c, 1);
  }
  if (rc != 0) {
    return (ERROR);
  }
}
<STRING>{BACKSLASH}             ;

<STRING>{QUOTES} {
  BEGIN(INITIAL);
  if (!string_error) {
    yylval.symbol = stringtable.add_string(string_buf, string_buf_ptr - string_buf);
    return (STR_CONST);
  }
}

{WHITESPACE}                     ;

<INITIAL>{TRUE}                  { yylval.boolean = true; return (BOOL_CONST); }
<INITIAL>{FALSE}                 { yylval.boolean = false; return (BOOL_CONST); }

<INITIAL>{CLASS}                 { return (CLASS); }
<INITIAL>{ELSE}                  { return (ELSE); }
<INITIAL>{FI}                    { return (FI); }
<INITIAL>{IF}                    { return (IF); }
<INITIAL>{IN}                    { return (IN); }
<INITIAL>{INHERITS}              { return (INHERITS); }
<INITIAL>{ISVOID}                { return (ISVOID); }
<INITIAL>{LET}                   { return (LET); }
<INITIAL>{LOOP}                  { return (LOOP); }
<INITIAL>{POOL}                  { return (POOL); }
<INITIAL>{THEN}                  { return (THEN); }
<INITIAL>{WHILE}                 { return (WHILE); }
<INITIAL>{CASE}                  { return (CASE); }
<INITIAL>{ESAC}                  { return (ESAC); }
<INITIAL>{NEW}                   { return (NEW); }
<INITIAL>{OF}                    { return (OF); }
<INITIAL>{NOT}                   { return (NOT); }
<INITIAL>{DARROW}		 { return (DARROW); }
<INITIAL>{ASSIGN}                { return (ASSIGN); }
<INITIAL>{LE}                    { return (LE); }

<INITIAL>{TYPEID}                { yylval.symbol = stringtable.add_string(yytext); return (TYPEID); }
<INITIAL>{OBJECTID}              { yylval.symbol = stringtable.add_string(yytext); return (OBJECTID); }
<INITIAL>{DIGIT}+                { yylval.symbol = stringtable.add_string(yytext); return (INT_CONST); }

<INITIAL>";"                     { return int(';'); }
<INITIAL>","                     { return int(','); }
<INITIAL>":"                     { return int(':'); }
<INITIAL>"{"                     { return int('{'); }
<INITIAL>"}"                     { return int('}'); }
<INITIAL>"+"                     { return int('+'); }
<INITIAL>"-"                     { return int('-'); }
<INITIAL>"*"                     { return int('*'); }
<INITIAL>"/"                     { return int('/'); }
<INITIAL>"<"                     { return int('<'); }
<INITIAL>"="                     { return int('='); }
<INITIAL>"~"                     { return int('~'); }
<INITIAL>"."                     { return int('.'); }
<INITIAL>"@"                     { return int('@'); }
<INITIAL>"("                     { return int('('); }
<INITIAL>")"                     { return int(')'); }

<INITIAL>.                       { yylval.error_msg = yytext; return (ERROR); }

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
