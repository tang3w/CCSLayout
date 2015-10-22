/* A Bison parser, made by GNU Bison 3.0.2.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2013 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

#ifndef YY_CCSLAYOUT_CCSLAYOUTPARSER_H_INCLUDED
# define YY_CCSLAYOUT_CCSLAYOUTPARSER_H_INCLUDED
/* Debug traces.  */
#ifndef CCSLAYOUTDEBUG
# if defined YYDEBUG
#if YYDEBUG
#   define CCSLAYOUTDEBUG 1
#  else
#   define CCSLAYOUTDEBUG 0
#  endif
# else /* ! defined YYDEBUG */
#  define CCSLAYOUTDEBUG 0
# endif /* ! defined YYDEBUG */
#endif  /* ! defined CCSLAYOUTDEBUG */
#if CCSLAYOUTDEBUG
extern int ccslayoutdebug;
#endif
/* "%code requires" blocks.  */
#line 18 "CCSLayoutParser.y" /* yacc.c:1915  */

#define YYSTYPE CCSLAYOUTSTYPE

#define YY_DECL int ccslayoutlex \
    (YYSTYPE *yylval_param, yyscan_t yyscanner, CCSLAYOUT_AST **astpp)

struct CCSLAYOUT_AST {
    int node_type;
    struct CCSLAYOUT_AST *l;
    struct CCSLAYOUT_AST *r;
    union {
        float number;
        float percentage;
        char *coord;
    } value;
    void *data;
};

typedef struct CCSLAYOUT_AST CCSLAYOUT_AST;

CCSLAYOUT_AST *ccslayout_create_ast(int type, CCSLAYOUT_AST *l, CCSLAYOUT_AST *r);

int ccslayout_parse_rule(char *rule, CCSLAYOUT_AST **astpp);
void ccslayout_destroy_ast(CCSLAYOUT_AST *astp);

#line 78 "CCSLayoutParser.h" /* yacc.c:1915  */

/* Token type.  */
#ifndef CCSLAYOUTTOKENTYPE
# define CCSLAYOUTTOKENTYPE
  enum ccslayouttokentype
  {
    CCSLAYOUT_TOKEN_ATTR = 258,
    CCSLAYOUT_TOKEN_NUMBER = 259,
    CCSLAYOUT_TOKEN_PERCENTAGE = 260,
    CCSLAYOUT_TOKEN_PERCENTAGE_H = 261,
    CCSLAYOUT_TOKEN_PERCENTAGE_V = 262,
    CCSLAYOUT_TOKEN_COORD = 263,
    CCSLAYOUT_TOKEN_COORD_PERCENTAGE = 264,
    CCSLAYOUT_TOKEN_COORD_PERCENTAGE_H = 265,
    CCSLAYOUT_TOKEN_COORD_PERCENTAGE_V = 266,
    CCSLAYOUT_TOKEN_NIL = 267,
    CCSLAYOUT_TOKEN_ADD_ASSIGN = 268,
    CCSLAYOUT_TOKEN_SUB_ASSIGN = 269,
    CCSLAYOUT_TOKEN_MUL_ASSIGN = 270,
    CCSLAYOUT_TOKEN_DIV_ASSIGN = 271
  };
#endif

/* Value type.  */
#if ! defined CCSLAYOUTSTYPE && ! defined CCSLAYOUTSTYPE_IS_DECLARED
typedef CCSLAYOUT_AST * CCSLAYOUTSTYPE;
# define CCSLAYOUTSTYPE_IS_TRIVIAL 1
# define CCSLAYOUTSTYPE_IS_DECLARED 1
#endif



int ccslayoutparse (void *scanner, CCSLAYOUT_AST **astpp);

#endif /* !YY_CCSLAYOUT_CCSLAYOUTPARSER_H_INCLUDED  */
