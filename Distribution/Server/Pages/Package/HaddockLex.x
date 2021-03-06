--
-- Haddock - A Haskell Documentation Tool
--
-- (c) Simon Marlow 2002
--

{
{-# LANGUAGE BangPatterns #-}
-- Disable warnings that the generated code causes
{-# OPTIONS_GHC -fno-warn-deprecated-flags
                -fno-warn-unused-binds
                -fno-warn-unused-imports
                -fno-warn-unused-matches
                -fno-warn-missing-signatures
                -fno-warn-tabs #-}
module Distribution.Server.Pages.Package.HaddockLex (
        Token(..),
        tokenise
 ) where

import Data.Char
import Data.Word (Word8)
import Numeric
import Control.Monad (liftM)
}

$ws    = $white # \n
$digit = [0-9]
$hexdigit = [0-9a-fA-F]
$special =  [\"\@]
$alphanum = [A-Za-z0-9]
$ident    = [$alphanum \'\_\.\!\#\$\%\&\*\+\/\<\=\>\?\@\\\\\^\|\-\~]

:-

-- beginning of a paragraph
<0,para> {
 $ws* \n                ;
 $ws* \>                { begin birdtrack }
 $ws* [\*\-]            { token TokBullet `andBegin` string }
 $ws* \[                { token TokDefStart `andBegin` def }
 $ws* \( $digit+ \)     { token TokNumber `andBegin` string }
 $ws*                   { begin string }
}

-- beginning of a line
<line> {
  $ws* \>               { begin birdtrack }
  $ws* \n               { token TokPara `andBegin` para }
  -- Here, we really want to be able to say
  -- $ws* (\n | <eof>)  { token TokPara `andBegin` para}
  -- because otherwise a trailing line of whitespace will result in
  -- a spurious TokString at the end of a docstring.  We don't have <eof>,
  -- though (NOW I realise what it was for :-).  To get around this, we always
  -- append \n to the end of a docstring.
  ()                    { begin string }
}

<birdtrack> .*  \n?     { strtoken TokBirdTrack `andBegin` line }

<string,def> {
  $special                      { strtoken $ \s -> TokSpecial (head s) }
  \<\<.*\>\>                    { strtoken $ \s -> TokPic (init $ init $ tail $ tail s) }
  \<.*\>                        { strtoken $ \s -> TokURL (init (tail s)) }
  \#.*\#                        { strtoken $ \s -> TokAName (init (tail s)) }
  \/ [^\/]* \/                  { strtoken $ \s -> TokEmphasis (init (tail s)) }
  [\'\`] $ident+ [\'\`]         { ident }
  \\ .                          { strtoken (TokString . tail) }
  "&#" $digit+ \;               { strtoken $ \s -> TokString [chr (read (init (drop 2 s)))] }
  "&#" [xX] $hexdigit+ \;       { strtoken $ \s -> case readHex (init (drop 3 s)) of [(n,_)] -> TokString [chr n]; _ -> error "hexParser: Can't happen" }
  -- allow special characters through if they don't fit one of the previous
  -- patterns.
  [\/\'\`\<\#\&\\]                      { strtoken TokString }
  [^ $special \/ \< \# \n \'\` \& \\ \]]* \n { strtoken TokString `andBegin` line }
  [^ $special \/ \< \# \n \'\` \& \\ \]]+    { strtoken TokString }
}

<def> {
  \]                            { token TokDefEnd `andBegin` string }
}

-- ']' doesn't have any special meaning outside of the [...] at the beginning
-- of a definition paragraph.
<string> {
  \]                            { strtoken TokString }
}

{
data Token
  = TokPara
  | TokNumber
  | TokBullet
  | TokDefStart
  | TokDefEnd
  | TokSpecial Char
  | TokIdent String
  | TokString String
  | TokURL String
  | TokPic String
  | TokEmphasis String
  | TokAName String
  | TokBirdTrack String
  deriving Show

-- -----------------------------------------------------------------------------
-- Alex support stuff

type StartCode = Int
type Action = String -> StartCode -> (StartCode -> Either String [Token]) -> Either String [Token]

type AlexInput = (Char,String)

-- | For alex >= 3
--
-- See also alexGetChar
alexGetByte :: AlexInput -> Maybe (Word8, AlexInput)
alexGetByte (_, [])   = Nothing
alexGetByte (_, c:cs) = Just (fromIntegral (ord c), (c,cs))

-- | For alex < 3
--
-- See also alexGetByte
alexGetChar :: AlexInput -> Maybe (Char, AlexInput)
alexGetChar (_, [])   = Nothing
alexGetChar (_, c:cs) = Just (c, (c,cs))

alexInputPrevChar (c,_) = c

tokenise :: String -> Either String [Token]
tokenise str = let toks = go ('\n', eofHack str) para in {-trace (show toks)-} toks
  where go inp@(_,str') sc =
          case alexScan inp sc of
                AlexEOF -> Right []
                AlexError _ -> Left "lexical error"
                AlexSkip  inp' _       -> go inp' sc
                AlexToken inp' len act -> act (take len str') sc (\sc' -> go inp' sc')

-- NB. we add a final \n to the string, (see comment in the beginning of line
-- production above).
eofHack str = str++"\n"

andBegin  :: Action -> StartCode -> Action
andBegin act new_sc = \str _ cont -> act str new_sc cont

token :: Token -> Action
token t = \_ sc cont -> liftM (t :) (cont sc)

strtoken :: (String -> Token) -> Action
strtoken t = \str sc cont -> liftM (t str :) (cont sc)

begin :: StartCode -> Action
begin sc = \_ _ cont -> cont sc

-- -----------------------------------------------------------------------------
-- Lex a string as a Haskell identifier

ident :: Action
ident str sc cont = liftM (TokIdent str :) (cont sc)
}
