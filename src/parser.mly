/****************************************************************************/
/* Copyright (C) 2007-2009 Gacek                                            */
/*                                                                          */
/* This file is part of Abella.                                             */
/*                                                                          */
/* Abella is free software: you can redistribute it and/or modify           */
/* it under the terms of the GNU General Public License as published by     */
/* the Free Software Foundation, either version 3 of the License, or        */
/* (at your option) any later version.                                      */
/*                                                                          */
/* Abella is distributed in the hope that it will be useful,                */
/* but WITHOUT ANY WARRANTY; without even the implied warranty of           */
/* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            */
/* GNU General Public License for more details.                             */
/*                                                                          */
/* You should have received a copy of the GNU General Public License        */
/* along with Abella.  If not, see <http://www.gnu.org/licenses/>.          */
/****************************************************************************/

%token IMP COMMA DOT BSLASH LPAREN RPAREN TURN CONS EQ TRUE FALSE DEFEQ
%token IND INST APPLY CASE SEARCH TO ON WITH INTROS CUT ASSERT CLAUSEEQ
%token SKIP UNDO ABORT COIND LEFT RIGHT MONOTONE IMPORT
%token SPLIT SPLITSTAR UNFOLD KEEP CLEAR SPECIFICATION
%token THEOREM DEFINE PLUS CODEFINE SET ABBREV UNABBREV
%token COLON RARROW FORALL NABLA EXISTS STAR AT HASH OR AND LBRACK RBRACK

%token <int> NUM
%token <string> STRINGID QSTRING
%token EOF

/* Lower */

%nonassoc COMMA
%right RARROW
%left OR
%left AND

%nonassoc BSLASH
%right IMP
%nonassoc EQ

%right CONS

/* Higher */


%start metaterm term clauses top_command command contexted_term def
%start defs
%type <Term.term> term
%type <Types.clauses> clauses
%type <Types.def> def
%type <Types.def list> defs
%type <Types.command> command
%type <Metaterm.obj> contexted_term
%type <Metaterm.metaterm> metaterm
%type <Types.top_command> top_command

%%

hyp:
  | STRINGID                             { $1 }

id:
  | STRINGID                             { $1 }
  | IND                                  { "induction" }
  | INST                                 { "inst" }
  | APPLY                                { "apply" }
  | CASE                                 { "case" }
  | SEARCH                               { "search" }
  | TO                                   { "to" }
  | ON                                   { "on" }
  | WITH                                 { "with" }
  | INTROS                               { "intros" }
  | CUT                                  { "cut" }
  | ASSERT                               { "assert" }
  | SKIP                                 { "skip" }
  | UNDO                                 { "undo" }
  | ABORT                                { "abort" }
  | COIND                                { "coinduction" }
  | LEFT                                 { "left" }
  | RIGHT                                { "right" }
  | MONOTONE                             { "monotone" }
  | SPLIT                                { "split" }
  | UNFOLD                               { "unfold" }
  | KEEP                                 { "keep" }
  | CLEAR                                { "clear" }
  | ABBREV                               { "abbrev" }
  | UNABBREV                             { "unabbrev" }
  | THEOREM                              { "Theorem" }
  | IMPORT                               { "Import" }
  | SPECIFICATION                        { "Specification" }
  | DEFINE                               { "Define" }
  | CODEFINE                             { "CoDefine" }
  | SET                                  { "Set" }

/* These would cause significant shift/reduce conflicts */
/*  | FORALL                               { "forall" }  */
/*  | NABLA                                { "nabla" }   */
/*  | EXISTS                               { "exists" }  */

contexted_term:
  | context TURN term                    { Metaterm.context_obj $1 $3 }
  | term                                 { Metaterm.obj $1 }

context:
  | context COMMA term                   { Context.add $3 $1 }
  | term                                 { Context.add $1 Context.empty }

term:
  | term IMP term                        { Term.binop "=>" $1 $3 }
  | term CONS term                       { Term.binop "::" $1 $3 }
  | id BSLASH term                       { Term.abstract $1 $3 }
  | exp exp_list                         { Term.app $1 $2 }
  | exp                                  { $1 }

exp:
  | LPAREN term RPAREN                   { $2 }
  | id                                   { Term.const $1 }

exp_list:
  | exp exp_list                         { $1::$2 }
  | exp                                  { [$1] }
  | id BSLASH term                       { [Term.abstract $1 $3] }

clauses:
  | clause clauses                       { $1::$2 }
  |                                      { [] }

clause:
  | term DOT                             { ($1, []) }
  | term CLAUSEEQ clause_body DOT        { ($1, $3) }

clause_body:
  | term COMMA clause_body               { $1::$3 }
  | LPAREN term COMMA clause_body RPAREN { $2::$4 }
  | term                                 { [$1] }

defs:
  | def defs                             { $1::$2 }
  |                                      { [] }

def:
  | metaterm DOT                         { ($1, Metaterm.True) }
  | metaterm DEFEQ metaterm DOT          { ($1, $3) }

command:
  | IND ON num_list DOT                  { Types.Induction($3) }
  | COIND DOT                            { Types.CoInduction }
  | APPLY id TO hyp_list DOT             { Types.Apply($2, $4, []) }
  | APPLY id TO hyp_list WITH withs DOT  { Types.Apply($2, $4, $6) }
  | APPLY id WITH withs DOT              { Types.Apply($2, [], $4) }
  | APPLY id DOT                         { Types.Apply($2, [], []) }
  | CUT hyp WITH hyp DOT                 { Types.Cut($2, $4) }
  | INST hyp WITH id EQ term DOT         { Types.Inst($2, $4, $6) }
  | CASE hyp DOT                         { Types.Case($2, false) }
  | CASE hyp LPAREN KEEP RPAREN DOT      { Types.Case($2, true) }
  | ASSERT metaterm DOT                  { Types.Assert($2) }
  | EXISTS term DOT                      { Types.Exists($2) }
  | SEARCH DOT                           { Types.Search(None) }
  | SEARCH NUM DOT                       { Types.Search(Some $2) }
  | SPLIT DOT                            { Types.Split }
  | SPLITSTAR DOT                        { Types.SplitStar }
  | LEFT DOT                             { Types.Left }
  | RIGHT DOT                            { Types.Right }
  | INTROS DOT                           { Types.Intros }
  | SKIP DOT                             { Types.Skip }
  | ABORT DOT                            { Types.Abort }
  | UNDO DOT                             { Types.Undo }
  | UNFOLD DOT                           { Types.Unfold }
  | CLEAR hyp_list DOT                   { Types.Clear($2) }
  | ABBREV hyp QSTRING DOT               { Types.Abbrev($2, $3) }
  | UNABBREV hyp_list DOT                { Types.Unabbrev($2) }
  | MONOTONE hyp WITH term DOT           { Types.Monotone($2, $4) }
  | SET id id DOT                        { Types.Set($2, Types.Str $3) }
  | SET id NUM DOT                       { Types.Set($2, Types.Int $3) }
  | EOF                                  { raise End_of_file }

hyp_list:
  | hyp hyp_list                         { $1::$2 }
  | hyp                                  { [$1] }

num_list:
  | NUM num_list                         { $1::$2 }
  | NUM                                  { [$1] }

withs:
  | id EQ term COMMA withs               { ($1, $3) :: $5 }
  | id EQ term                           { [($1, $3)] }

metaterm:
  | TRUE                                 { Metaterm.True }
  | FALSE                                { Metaterm.False }
  | term EQ term                         { Metaterm.Eq($1, $3) }
  | FORALL binding_list COMMA metaterm   { Metaterm.forall $2 $4 }
  | EXISTS binding_list COMMA metaterm   { Metaterm.exists $2 $4 }
  | NABLA binding_list COMMA metaterm    { Metaterm.nabla $2 $4 }
  | metaterm RARROW metaterm             { Metaterm.arrow $1 $3 }
  | metaterm OR metaterm                 { Metaterm.meta_or $1 $3 }
  | metaterm AND metaterm                { Metaterm.meta_and $1 $3 }
  | LPAREN metaterm RPAREN               { $2 }
  | LBRACK contexted_term RBRACK restriction
                                         { Metaterm.Obj($2, $4) }
  | term restriction                     { Metaterm.Pred($1, $2) }

binding_list:
  | binding binding_list                 { $1::$2 }
  | binding                              { [$1] }

binding:
  | id                                   { $1 }

restriction:
  |                                      { Metaterm.Irrelevant }
  | stars                                { Metaterm.Smaller $1 }
  | pluses                               { Metaterm.CoSmaller $1 }
  | ats                                  { Metaterm.Equal $1 }
  | hashes                               { Metaterm.CoEqual $1 }

stars:
  | STAR stars                           { 1 + $2 }
  | STAR                                 { 1 }

ats:
  | AT ats                               { 1 + $2 }
  | AT                                   { 1 }

pluses:
  | PLUS pluses                          { 1 + $2 }
  | PLUS                                 { 1 }

hashes:
  | HASH hashes                          { 1 + $2 }
  | HASH                                 { 1 }

top_command :
  | THEOREM id COLON metaterm DOT        { Types.Theorem($2, $4) }
  | THEOREM metaterm DOT                 { Types.Theorem("Goal", $2) }
  | DEFINE def                           { Types.Define($2) }
  | CODEFINE def                         { Types.CoDefine($2) }
  | SET id id DOT                        { Types.TopSet($2, Types.Str $3) }
  | SET id NUM DOT                       { Types.TopSet($2, Types.Int $3) }
  | IMPORT QSTRING DOT                   { Types.Import($2) }
  | SPECIFICATION QSTRING DOT            { Types.Specification($2) }
  | EOF                                  { raise End_of_file }
