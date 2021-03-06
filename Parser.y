{

module Parser where
import Control.Monad.Error
import RawSyntax
import Lexer
import Common
import Text.PrettyPrint((<>),(<+>),char,text)

}

%name main ListSmt
%error { parseError }
%monad { Err } { thenM } { returnM }
%tokentype { Token }

%token
let      { PT $$ T_Let }
case     { PT $$ T_Case }
in       { PT $$ T_In }
'λ'	 { PT _ T_Lambda }
'.'      { PT _ T_DOT }
'→'	 { PT _ T_To }
'*'      { PT $$ T_Star }
'×'      { PT _ T_Cross }
'('	 { PT _ T_PARL }
')'	 { PT _ T_PARR }
'{'	 { PT _ T_ACCL }
'}'	 { PT _ T_ACCR }
','	 { PT _ T_COMMA }
'::'	 { PT _ T_2COLON }
':'	 { PT _ T_COLON }
'='	 { PT _ T_EQUAL }
T_Tag    { PT _ (T_Tag _) }
T_Ident  { PT _ (T_Ident _) }
T_Int    { PT _ (T_Int $$) }
L_err    { _ }


%%

ListSmt :: { [Smt] }
ListSmt : {- empty -} { [] }
        | Smt ListSmt { $1 : $2 }

Smt :: { Smt }
Smt : Ident '::' Term  { TypDec $1 $3 }
    | Ident '=' Term  { Def $1 $3 }

Ident :: { Ident }
Ident :
  T_Ident { case $1 of PT pos (T_Ident x) -> Ident (pos,x) }

Tag :: { Tag }
Tag :
  T_Tag   { case $1 of PT pos (T_Tag x) -> TTag (pos,x) }


VarType :: { VarType }
VarType : Ident ':' Ident { ($1,$3) }
  | '(' Ident ':' Ident ')' { ($2,$4) }

Pair :: { Pair }
Pair : Ident ',' Ident { ($1,$3) }
  | '(' Ident ',' Ident ')' { ($2,$4) }


Cross :: { () }
Cross : '*' { () }
      | '×' { () }

Term :: { Term }
Term : Ident { Var $1 }

 -- let i : C = (x:A)→<B> in <t>
  | let Ident ':' Star '=' VarType '→' Term in Term
  { Pi $1 $2      (snd $4) $6          $8   $9 $10 }

 -- let i : C = λx.<t'> in <t>
  | let Ident ':' Ident '=' 'λ' Ident '.' Term in Term
  { Lam $1 $2     $4            $7        $9   $10 $11 }

 -- let i = f x in <t>
  | let Ident '=' Ident Ident in Term
  { App $1 $2     $4    $5    $6 $7 }

 -- let i : C  = (x:A)×<B> in <t>
  | let Ident ':' Star '=' VarType Cross Term in Term
  { Sigma $1 $2   (snd $4) $6            $8   $9 $10 }

 -- let i : C = (x,y) in t
  | let Ident ':' Ident '=' Pair in Term
  { Pair $1 $2    $4        $6   $7 $8 }

 -- let (x,y) = z in <t>
  | let Pair  '=' Ident in Term
  { Proj $1 $2    $4    $5 $6 }

 -- let i = { 'tagᵢ | i = 1..n } in <t>
  | let Ident '=' '{' TagsOrEmpty '}' in Term
  { Fin $1 $2         $5              $7 $8 }

 -- let i : T = 'tagᵢ in <t>
  | let Ident ':' Ident '=' Tag in Term
  { Tag $1 $2     $4        $6  $7 $8 }

 -- case x { 'tagᵢ → <tᵢ> | i = 1..n }
  | case Ident '{' ListCaseCont '}'
  { Case $1 $2     $4 }

 -- *ᵢ
  | Star
   { let (pos, i) = $1 in Star pos i }

TagsOrEmpty :: { [Tag] }
TagsOrEmpty : {- empty -} { [] } | Tags { $1 }

Tags :: { [Tag] }
Tags : Tag { [$1] }
     | Tag ',' Tags { $1 : $3 }

ListCaseCont :: { [CaseCont] }
ListCaseCont : {- empty -} { [] }
  | CaseCont ListCaseCont { $1 : $2 }

CaseCont :: { CaseCont }
CaseCont : Tag '→' Term { CaseCont $1 $3 }

Star :: { (Position, Int) }
Star : '*' { ($1, 1) }
  | '*' T_Int { ($1, $2) }

{

returnM :: a -> Err a
returnM = return

thenM :: Err a -> (a -> Err b) -> Err b
thenM = (>>=)

parseError :: [Token] -> Err a
parseError [] = throwError $ text "Syntax error." -- TODO
parseError ts =
  throwError $
  text "Syntax error at" <+>
  text (show (tokenPosn (head ts))) <>
  case ts of
    [] -> char '.'
    [Err _] -> text " due to lexer error."
    _ -> char '.'

}
