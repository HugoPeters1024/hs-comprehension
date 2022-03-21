{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE DisambiguateRecordFields #-}
module Generation where

import Data.String (IsString(..))
import Control.Monad (forM_)
import Text.Blaze.Html5 as H
import Text.Blaze.Html5.Attributes as A
import Text.Blaze.Html.Renderer.Utf8 (renderHtml)
import System.IO.Temp
import System.IO
import qualified Data.ByteString as BS

import GHC.Plugins
import System.Process

import qualified Data.String.Interpolate as I (i)
import PrettyPrinting
import qualified CoreCollection as CC

data PassView  = PassView { info :: CC.PassInfo
                          , prevPass :: Maybe PassView
                          , nextPass :: Maybe PassView
                          , filepath :: FilePath
                          , ast_filepath :: FilePath
                          }

data GlobalPassInfo = GlobalPassInfo { nrViews :: Int
                                     }

collectInfo :: [PassView] -> GlobalPassInfo
collectInfo views = GlobalPassInfo { nrViews = length views
                                   }


infoToView :: CC.PassInfo -> IO PassView
infoToView info = do
    let idx = info.idx
    let path = [I.i|/tmp/hs-comprehension-#{idx}.html|]
    let ast_path = [I.i|/tmp/hs-comprehension-ast-#{idx}.html|]

    let code = info.ast
    withFile ast_path WriteMode $ \h -> BS.hPut h [I.i|#{code}|]

    pure $ PassView { info = info
                    , prevPass = Nothing
                    , nextPass = Nothing
                    , filepath = path
                    , ast_filepath = ast_path
                    }


codeBlock :: String -> Html
codeBlock code = H.pre ! A.class_ "code"  $ H.unsafeByteString [I.i| #{code}|]

maybeHtml :: Maybe Html -> Html
maybeHtml Nothing = pure ()
maybeHtml (Just html) = html

buttonToPass :: PassView -> Html
buttonToPass view = H.a ! A.href [I.i|#{filepath view}|] $ do
                        H.button (toHtml view.info.title)


renderPass :: GlobalPassInfo -> PassView -> IO Html
renderPass globals view = do
    guts_colored <- highlight view.info.ast
    diff_colored <- case view.prevPass of
                        Nothing -> pure ""
                        Just prevPass -> diffFiles prevPass.ast_filepath view.ast_filepath
    pure $ docTypeHtml $ do
        H.head $ do
            H.title $ H.string view.info.title
            H.style $ do
                H.unsafeByteString myCss
                H.unsafeByteString pygmentCss
                H.unsafeByteString ansiCss
        H.body $ do
            let title = view.info.title
                idx = view.info.idx
                total = globals.nrViews
            H.h1 $ [I.i|#{title} #{idx}/#{total}|]
            H.hr
            H.div $ do
                maybeHtml $ buttonToPass <$> view.prevPass
                maybeHtml $ buttonToPass <$> view.nextPass
            H.hr
            codeBlock guts_colored
            maybeHtml $ view.prevPass >>= \prevPass -> Just $ H.p $ do
                let hrefv = prevPass.ast_filepath
                (H.a ! A.href [I.i|#{hrefv}|]) (H.string prevPass.ast_filepath)
            maybeHtml $ view.nextPass >>= \nextPass -> Just $ H.p $ do
                let hrefv = nextPass.ast_filepath
                (H.a ! A.href [I.i|#{hrefv}|]) (H.string nextPass.ast_filepath)
            codeBlock diff_colored
        
saveToFile :: FilePath -> Html -> IO ()
saveToFile path html = 
    let 
        bs :: BS.ByteString
        bs = BS.toStrict $ renderHtml html 
    in 
        withFile path WriteMode $ \handle -> do
            BS.hPutStr handle bs
            putStrLn $ "file://" ++ path

highlight :: String -> IO String
highlight = readProcess "/home/hugo/repos/hs-comprehension/hs-comprehension/scripts/hightlight.py" []

diffFiles :: FilePath -> FilePath -> IO String
diffFiles lhs rhs = do
    ret <- readProcess "/home/hugo/repos/hs-comprehension/hs-comprehension/scripts/diff.sh" [lhs, rhs] mempty
    pure $ if ret == mempty then "The files are the same" else ret

myCss :: BS.ByteString
myCss = [I.i|
|]

pygmentCss :: BS.ByteString
pygmentCss = [I.i| 
    .hll { background-color: #49483e }
    .c { color: #95917e } /* Comment */
    .err { color: #960050; background-color: #1e0010 } /* Error */
    .k { color: #66d9ef } /* Keyword */
    .l { color: #ae81ff } /* Literal */
    .n { color: #f8f8f2 } /* Name */
    .o { color: #f92672 } /* Operator */
    .p { color: #f8f8f2 } /* Punctuation */
    .ch { color: #75715e } /* Comment.Hashbang */
    .cm { color: #75715e } /* Comment.Multiline */
    .cp { color: #75715e } /* Comment.Preproc */
    .cpf { color: #75715e } /* Comment.PreprocFile */
    .c1 { color: #95917e } /* Comment.Single */
    .cs { color: #75715e } /* Comment.Special */
    .gd { color: #f92672 } /* Generic.Deleted */
    .ge { font-style: italic } /* Generic.Emph */
    .gi { color: #a6e22e } /* Generic.Inserted */
    .gs { font-weight: bold } /* Generic.Strong */
    .gu { color: #75715e } /* Generic.Subheading */
    .kc { color: #66d9ef } /* Keyword.Constant */
    .kd { color: #66d9ef } /* Keyword.Declaration */
    .kn { color: #f92672 } /* Keyword.Namespace */
    .kp { color: #66d9ef } /* Keyword.Pseudo */
    .kr { color: #66d9ef } /* Keyword.Reserved */
    .kt { color: #66d9ef } /* Keyword.Type */
    .ld { color: #e6db74 } /* Literal.Date */
    .m { color: #ae81ff } /* Literal.Number */
    .s { color: #e6db74 } /* Literal.String */
    .na { color: #a6e22e } /* Name.Attribute */
    .nb { color: #f8f8f2 } /* Name.Builtin */
    .nc { color: #a6e22e } /* Name.Class */
    .no { color: #66d9ef } /* Name.Constant */
    .nd { color: #a6e22e } /* Name.Decorator */
    .ni { color: #f8f8f2 } /* Name.Entity */
    .ne { color: #a6e22e } /* Name.Exception */
    .nf { color: #a6e22e } /* Name.Function */
    .nl { color: #f8f8f2 } /* Name.Label */
    .nn { color: #f8f8f2 } /* Name.Namespace */
    .nx { color: #a6e22e } /* Name.Other */
    .py { color: #f8f8f2 } /* Name.Property */
    .nt { color: #f92672 } /* Name.Tag */
    .nv { color: #f8f8f2 } /* Name.Variable */
    .ow { color: #f92672 } /* Operator.Word */
    .w { color: #f8f8f2 } /* Text.Whitespace */
    .mb { color: #ae81ff } /* Literal.Number.Bin */
    .mf { color: #ae81ff } /* Literal.Number.Float */
    .mh { color: #ae81ff } /* Literal.Number.Hex */
    .mi { color: #ae81ff } /* Literal.Number.Integer */
    .mo { color: #ae81ff } /* Literal.Number.Oct */
    .sa { color: #e6db74 } /* Literal.String.Affix */
    .sb { color: #e6db74 } /* Literal.String.Backtick */
    .dl { color: #e6db74 } /* Literal.String.Delimiter */
    .sd { color: #e6db74 } /* Literal.String.Doc */
    .s2 { color: #e6db74 } /* Literal.String.Double */
    .se { color: #ae81ff } /* Literal.String.Escape */
    .sh { color: #e6db74 } /* Literal.String.Heredoc */
    .si { color: #e6db74 } /* Literal.String.Interpol */
    .sx { color: #e6db74 } /* Literal.String.Other */
    .sr { color: #e6db74 } /* Literal.String.Regex */
    .s1 { color: #e6db74 } /* Literal.String.Single */
    .ss { color: #e6db74 } /* Literal.String.Symbol */
    .bp { color: #f8f8f2 } /* Name.Builtin.Pseudo */
    .fm { color: #a6e22e } /* Name.Function.Magic */
    .vc { color: #f8f8f2 } /* Name.Variable.Class */
    .vg { color: #f8f8f2 } /* Name.Variable.Global */
    .vi { color: #f8f8f2 } /* Name.Variable.Instance */
    .vm { color: #f8f8f2 } /* Name.Variable.Magic */
    .il { color: #ae81ff } /* Literal.Number.Integer.Long */
    pre.code { color: #FFFFFF; background-color: #173E46; padding: 2em; }
    |]

ansiCss :: BS.ByteString
ansiCss = [I.i|
    .ansi2html-content { display: inline; white-space: pre-wrap; word-wrap: break-word; }
    .body_foreground { color: #AAAAAA; }
    .body_background { background-color: #000000; }
    .body_foreground > .bold,.bold > .body_foreground, body.body_foreground > pre > .bold { color: #FFFFFF; font-weight: normal; }
    .inv_foreground { color: #000000; }
    .inv_background { background-color: #AAAAAA; }
    .ansi1 { font-weight: bold; }
    .ansi2 { font-weight: lighter; }
    .ansi3 { font-style: italic; }
    .ansi4 { text-decoration: underline; }
    .ansi5 { text-decoration: blink; }
    .ansi6 { text-decoration: blink; }
    .ansi8 { visibility: hidden; }
    .ansi9 { text-decoration: line-through; }
    .ansi30 { color: #000316; }
    .inv30 { background-color: #000316; }
    .ansi31 { color: #aa0000; }
    .inv31 { background-color: #aa0000; }
    .ansi32 { color: #00aa00; }
    .inv32 { background-color: #00aa00; }
    .ansi33 { color: #aa5500; }
    .inv33 { background-color: #aa5500; }
    .ansi34 { color: #0000aa; }
    .inv34 { background-color: #0000aa; }
    .ansi35 { color: #E850A8; }
    .inv35 { background-color: #E850A8; }
    .ansi36 { color: #00aaaa; }
    .inv36 { background-color: #00aaaa; }
    .ansi37 { color: #F5F1DE; }
    .inv37 { background-color: #F5F1DE; }
    .ansi40 { background-color: #000316; }
    .inv40 { color: #000316; }
    .ansi41 { background-color: #aa0000; }
    .inv41 { color: #aa0000; }
    .ansi42 { background-color: #00aa00; }
    .inv42 { color: #00aa00; }
    .ansi43 { background-color: #aa5500; }
    .inv43 { color: #aa5500; }
    .ansi44 { background-color: #0000aa; }
    .inv44 { color: #0000aa; }
    .ansi45 { background-color: #E850A8; }
    .inv45 { color: #E850A8; }
    .ansi46 { background-color: #00aaaa; }
    .inv46 { color: #00aaaa; }
    .ansi47 { background-color: #F5F1DE; }
    .inv47 { color: #F5F1DE; }
    .ansi90 { color: #404356; }
    .inv90 { background-color: #404356; }
    .ansi91 { color: #ea4040; }
    .inv91 { background-color: #ea4040; }
    .ansi92 { color: #40ea40; }
    .inv92 { background-color: #40ea40; }
    .ansi93 { color: #ea9540; }
    .inv93 { background-color: #ea9540; }
    .ansi94 { color: #4040ea; }
    .inv94 { background-color: #4040ea; }
    .ansi95 { color: #ff90e8; }
    .inv95 { background-color: #ff90e8; }
    .ansi96 { color: #40eaea; }
    .inv96 { background-color: #40eaea; }
    .ansi97 { color: #ffffff; }
    .inv97 { background-color: #ffffff; }
    .ansi100 { background-color: #404356; }
    .inv100 { color: #404356; }
    .ansi101 { background-color: #ea4040; }
    .inv101 { color: #ea4040; }
    .ansi102 { background-color: #40ea40; }
    .inv102 { color: #40ea40; }
    .ansi103 { background-color: #ea9540; }
    .inv103 { color: #ea9540; }
    .ansi104 { background-color: #4040ea; }
    .inv104 { color: #4040ea; }
    .ansi105 { background-color: #ff90e8; }
    .inv105 { color: #ff90e8; }
    .ansi106 { background-color: #40eaea; }
    .inv106 { color: #40eaea; }
    .ansi107 { background-color: #ffffff; }
    .inv107 { color: #ffffff; }
    .ansi38-0 { color: #000316; }
    .inv38-0 { background-color: #000316; }
    .ansi38-1 { color: #aa0000; }
    .inv38-1 { background-color: #aa0000; }
    .ansi38-2 { color: #00aa00; }
    .inv38-2 { background-color: #00aa00; }
    .ansi38-3 { color: #aa5500; }
    .inv38-3 { background-color: #aa5500; }
    .ansi38-4 { color: #0000aa; }
    .inv38-4 { background-color: #0000aa; }
    .ansi38-5 { color: #E850A8; }
    .inv38-5 { background-color: #E850A8; }
    .ansi38-6 { color: #00aaaa; }
    .inv38-6 { background-color: #00aaaa; }
    .ansi38-7 { color: #F5F1DE; }
    .inv38-7 { background-color: #F5F1DE; }
    .ansi38-8 { color: #7f7f7f; }
    .inv38-8 { background-color: #7f7f7f; }
    .ansi38-9 { color: #ff0000; }
    .inv38-9 { background-color: #ff0000; }
    .ansi38-10 { color: #00ff00; }
    .inv38-10 { background-color: #00ff00; }
    .ansi38-11 { color: #ffff00; }
    .inv38-11 { background-color: #ffff00; }
    .ansi38-12 { color: #5c5cff; }
    .inv38-12 { background-color: #5c5cff; }
    .ansi38-13 { color: #ff00ff; }
    .inv38-13 { background-color: #ff00ff; }
    .ansi38-14 { color: #00ffff; }
    .inv38-14 { background-color: #00ffff; }
    .ansi38-15 { color: #ffffff; }
    .inv38-15 { background-color: #ffffff; }
    .ansi48-0 { background-color: #000316; }
    .inv48-0 { color: #000316; }
    .ansi48-1 { background-color: #aa0000; }
    .inv48-1 { color: #aa0000; }
    .ansi48-2 { background-color: #00aa00; }
    .inv48-2 { color: #00aa00; }
    .ansi48-3 { background-color: #aa5500; }
    .inv48-3 { color: #aa5500; }
    .ansi48-4 { background-color: #0000aa; }
    .inv48-4 { color: #0000aa; }
    .ansi48-5 { background-color: #E850A8; }
    .inv48-5 { color: #E850A8; }
    .ansi48-6 { background-color: #00aaaa; }
    .inv48-6 { color: #00aaaa; }
    .ansi48-7 { background-color: #F5F1DE; }
    .inv48-7 { color: #F5F1DE; }
    .ansi48-8 { background-color: #7f7f7f; }
    .inv48-8 { color: #7f7f7f; }
    .ansi48-9 { background-color: #ff0000; }
    .inv48-9 { color: #ff0000; }
    .ansi48-10 { background-color: #00ff00; }
    .inv48-10 { color: #00ff00; }
    .ansi48-11 { background-color: #ffff00; }
    .inv48-11 { color: #ffff00; }
    .ansi48-12 { background-color: #5c5cff; }
    .inv48-12 { color: #5c5cff; }
    .ansi48-13 { background-color: #ff00ff; }
    .inv48-13 { color: #ff00ff; }
    .ansi48-14 { background-color: #00ffff; }
    .inv48-14 { color: #00ffff; }
    .ansi48-15 { background-color: #ffffff; }
    .inv48-15 { color: #ffffff; }
    .ansi38-16 { color: #000000; }
    .inv38-16 { background: #000000; }
    .ansi48-16 { background: #000000; }
    .inv48-16 { color: #000000; }
    .ansi38-17 { color: #00005f; }
    .inv38-17 { background: #00005f; }
    .ansi48-17 { background: #00005f; }
    .inv48-17 { color: #00005f; }
    .ansi38-18 { color: #000087; }
    .inv38-18 { background: #000087; }
    .ansi48-18 { background: #000087; }
    .inv48-18 { color: #000087; }
    .ansi38-19 { color: #0000af; }
    .inv38-19 { background: #0000af; }
    .ansi48-19 { background: #0000af; }
    .inv48-19 { color: #0000af; }
    .ansi38-20 { color: #0000d7; }
    .inv38-20 { background: #0000d7; }
    .ansi48-20 { background: #0000d7; }
    .inv48-20 { color: #0000d7; }
    .ansi38-21 { color: #0000ff; }
    .inv38-21 { background: #0000ff; }
    .ansi48-21 { background: #0000ff; }
    .inv48-21 { color: #0000ff; }
    .ansi38-52 { color: #5f0000; }
    .inv38-52 { background: #5f0000; }
    .ansi48-52 { background: #5f0000; }
    .inv48-52 { color: #5f0000; }
    .ansi38-53 { color: #5f005f; }
    .inv38-53 { background: #5f005f; }
    .ansi48-53 { background: #5f005f; }
    .inv48-53 { color: #5f005f; }
    .ansi38-54 { color: #5f0087; }
    .inv38-54 { background: #5f0087; }
    .ansi48-54 { background: #5f0087; }
    .inv48-54 { color: #5f0087; }
    .ansi38-55 { color: #5f00af; }
    .inv38-55 { background: #5f00af; }
    .ansi48-55 { background: #5f00af; }
    .inv48-55 { color: #5f00af; }
    .ansi38-56 { color: #5f00d7; }
    .inv38-56 { background: #5f00d7; }
    .ansi48-56 { background: #5f00d7; }
    .inv48-56 { color: #5f00d7; }
    .ansi38-57 { color: #5f00ff; }
    .inv38-57 { background: #5f00ff; }
    .ansi48-57 { background: #5f00ff; }
    .inv48-57 { color: #5f00ff; }
    .ansi38-88 { color: #870000; }
    .inv38-88 { background: #870000; }
    .ansi48-88 { background: #870000; }
    .inv48-88 { color: #870000; }
    .ansi38-89 { color: #87005f; }
    .inv38-89 { background: #87005f; }
    .ansi48-89 { background: #87005f; }
    .inv48-89 { color: #87005f; }
    .ansi38-90 { color: #870087; }
    .inv38-90 { background: #870087; }
    .ansi48-90 { background: #870087; }
    .inv48-90 { color: #870087; }
    .ansi38-91 { color: #8700af; }
    .inv38-91 { background: #8700af; }
    .ansi48-91 { background: #8700af; }
    .inv48-91 { color: #8700af; }
    .ansi38-92 { color: #8700d7; }
    .inv38-92 { background: #8700d7; }
    .ansi48-92 { background: #8700d7; }
    .inv48-92 { color: #8700d7; }
    .ansi38-93 { color: #8700ff; }
    .inv38-93 { background: #8700ff; }
    .ansi48-93 { background: #8700ff; }
    .inv48-93 { color: #8700ff; }
    .ansi38-124 { color: #af0000; }
    .inv38-124 { background: #af0000; }
    .ansi48-124 { background: #af0000; }
    .inv48-124 { color: #af0000; }
    .ansi38-125 { color: #af005f; }
    .inv38-125 { background: #af005f; }
    .ansi48-125 { background: #af005f; }
    .inv48-125 { color: #af005f; }
    .ansi38-126 { color: #af0087; }
    .inv38-126 { background: #af0087; }
    .ansi48-126 { background: #af0087; }
    .inv48-126 { color: #af0087; }
    .ansi38-127 { color: #af00af; }
    .inv38-127 { background: #af00af; }
    .ansi48-127 { background: #af00af; }
    .inv48-127 { color: #af00af; }
    .ansi38-128 { color: #af00d7; }
    .inv38-128 { background: #af00d7; }
    .ansi48-128 { background: #af00d7; }
    .inv48-128 { color: #af00d7; }
    .ansi38-129 { color: #af00ff; }
    .inv38-129 { background: #af00ff; }
    .ansi48-129 { background: #af00ff; }
    .inv48-129 { color: #af00ff; }
    .ansi38-160 { color: #d70000; }
    .inv38-160 { background: #d70000; }
    .ansi48-160 { background: #d70000; }
    .inv48-160 { color: #d70000; }
    .ansi38-161 { color: #d7005f; }
    .inv38-161 { background: #d7005f; }
    .ansi48-161 { background: #d7005f; }
    .inv48-161 { color: #d7005f; }
    .ansi38-162 { color: #d70087; }
    .inv38-162 { background: #d70087; }
    .ansi48-162 { background: #d70087; }
    .inv48-162 { color: #d70087; }
    .ansi38-163 { color: #d700af; }
    .inv38-163 { background: #d700af; }
    .ansi48-163 { background: #d700af; }
    .inv48-163 { color: #d700af; }
    .ansi38-164 { color: #d700d7; }
    .inv38-164 { background: #d700d7; }
    .ansi48-164 { background: #d700d7; }
    .inv48-164 { color: #d700d7; }
    .ansi38-165 { color: #d700ff; }
    .inv38-165 { background: #d700ff; }
    .ansi48-165 { background: #d700ff; }
    .inv48-165 { color: #d700ff; }
    .ansi38-196 { color: #ff0000; }
    .inv38-196 { background: #ff0000; }
    .ansi48-196 { background: #ff0000; }
    .inv48-196 { color: #ff0000; }
    .ansi38-197 { color: #ff005f; }
    .inv38-197 { background: #ff005f; }
    .ansi48-197 { background: #ff005f; }
    .inv48-197 { color: #ff005f; }
    .ansi38-198 { color: #ff0087; }
    .inv38-198 { background: #ff0087; }
    .ansi48-198 { background: #ff0087; }
    .inv48-198 { color: #ff0087; }
    .ansi38-199 { color: #ff00af; }
    .inv38-199 { background: #ff00af; }
    .ansi48-199 { background: #ff00af; }
    .inv48-199 { color: #ff00af; }
    .ansi38-200 { color: #ff00d7; }
    .inv38-200 { background: #ff00d7; }
    .ansi48-200 { background: #ff00d7; }
    .inv48-200 { color: #ff00d7; }
    .ansi38-201 { color: #ff00ff; }
    .inv38-201 { background: #ff00ff; }
    .ansi48-201 { background: #ff00ff; }
    .inv48-201 { color: #ff00ff; }
    .ansi38-22 { color: #005f00; }
    .inv38-22 { background: #005f00; }
    .ansi48-22 { background: #005f00; }
    .inv48-22 { color: #005f00; }
    .ansi38-23 { color: #005f5f; }
    .inv38-23 { background: #005f5f; }
    .ansi48-23 { background: #005f5f; }
    .inv48-23 { color: #005f5f; }
    .ansi38-24 { color: #005f87; }
    .inv38-24 { background: #005f87; }
    .ansi48-24 { background: #005f87; }
    .inv48-24 { color: #005f87; }
    .ansi38-25 { color: #005faf; }
    .inv38-25 { background: #005faf; }
    .ansi48-25 { background: #005faf; }
    .inv48-25 { color: #005faf; }
    .ansi38-26 { color: #005fd7; }
    .inv38-26 { background: #005fd7; }
    .ansi48-26 { background: #005fd7; }
    .inv48-26 { color: #005fd7; }
    .ansi38-27 { color: #005fff; }
    .inv38-27 { background: #005fff; }
    .ansi48-27 { background: #005fff; }
    .inv48-27 { color: #005fff; }
    .ansi38-58 { color: #5f5f00; }
    .inv38-58 { background: #5f5f00; }
    .ansi48-58 { background: #5f5f00; }
    .inv48-58 { color: #5f5f00; }
    .ansi38-59 { color: #5f5f5f; }
    .inv38-59 { background: #5f5f5f; }
    .ansi48-59 { background: #5f5f5f; }
    .inv48-59 { color: #5f5f5f; }
    .ansi38-60 { color: #5f5f87; }
    .inv38-60 { background: #5f5f87; }
    .ansi48-60 { background: #5f5f87; }
    .inv48-60 { color: #5f5f87; }
    .ansi38-61 { color: #5f5faf; }
    .inv38-61 { background: #5f5faf; }
    .ansi48-61 { background: #5f5faf; }
    .inv48-61 { color: #5f5faf; }
    .ansi38-62 { color: #5f5fd7; }
    .inv38-62 { background: #5f5fd7; }
    .ansi48-62 { background: #5f5fd7; }
    .inv48-62 { color: #5f5fd7; }
    .ansi38-63 { color: #5f5fff; }
    .inv38-63 { background: #5f5fff; }
    .ansi48-63 { background: #5f5fff; }
    .inv48-63 { color: #5f5fff; }
    .ansi38-94 { color: #875f00; }
    .inv38-94 { background: #875f00; }
    .ansi48-94 { background: #875f00; }
    .inv48-94 { color: #875f00; }
    .ansi38-95 { color: #875f5f; }
    .inv38-95 { background: #875f5f; }
    .ansi48-95 { background: #875f5f; }
    .inv48-95 { color: #875f5f; }
    .ansi38-96 { color: #875f87; }
    .inv38-96 { background: #875f87; }
    .ansi48-96 { background: #875f87; }
    .inv48-96 { color: #875f87; }
    .ansi38-97 { color: #875faf; }
    .inv38-97 { background: #875faf; }
    .ansi48-97 { background: #875faf; }
    .inv48-97 { color: #875faf; }
    .ansi38-98 { color: #875fd7; }
    .inv38-98 { background: #875fd7; }
    .ansi48-98 { background: #875fd7; }
    .inv48-98 { color: #875fd7; }
    .ansi38-99 { color: #875fff; }
    .inv38-99 { background: #875fff; }
    .ansi48-99 { background: #875fff; }
    .inv48-99 { color: #875fff; }
    .ansi38-130 { color: #af5f00; }
    .inv38-130 { background: #af5f00; }
    .ansi48-130 { background: #af5f00; }
    .inv48-130 { color: #af5f00; }
    .ansi38-131 { color: #af5f5f; }
    .inv38-131 { background: #af5f5f; }
    .ansi48-131 { background: #af5f5f; }
    .inv48-131 { color: #af5f5f; }
    .ansi38-132 { color: #af5f87; }
    .inv38-132 { background: #af5f87; }
    .ansi48-132 { background: #af5f87; }
    .inv48-132 { color: #af5f87; }
    .ansi38-133 { color: #af5faf; }
    .inv38-133 { background: #af5faf; }
    .ansi48-133 { background: #af5faf; }
    .inv48-133 { color: #af5faf; }
    .ansi38-134 { color: #af5fd7; }
    .inv38-134 { background: #af5fd7; }
    .ansi48-134 { background: #af5fd7; }
    .inv48-134 { color: #af5fd7; }
    .ansi38-135 { color: #af5fff; }
    .inv38-135 { background: #af5fff; }
    .ansi48-135 { background: #af5fff; }
    .inv48-135 { color: #af5fff; }
    .ansi38-166 { color: #d75f00; }
    .inv38-166 { background: #d75f00; }
    .ansi48-166 { background: #d75f00; }
    .inv48-166 { color: #d75f00; }
    .ansi38-167 { color: #d75f5f; }
    .inv38-167 { background: #d75f5f; }
    .ansi48-167 { background: #d75f5f; }
    .inv48-167 { color: #d75f5f; }
    .ansi38-168 { color: #d75f87; }
    .inv38-168 { background: #d75f87; }
    .ansi48-168 { background: #d75f87; }
    .inv48-168 { color: #d75f87; }
    .ansi38-169 { color: #d75faf; }
    .inv38-169 { background: #d75faf; }
    .ansi48-169 { background: #d75faf; }
    .inv48-169 { color: #d75faf; }
    .ansi38-170 { color: #d75fd7; }
    .inv38-170 { background: #d75fd7; }
    .ansi48-170 { background: #d75fd7; }
    .inv48-170 { color: #d75fd7; }
    .ansi38-171 { color: #d75fff; }
    .inv38-171 { background: #d75fff; }
    .ansi48-171 { background: #d75fff; }
    .inv48-171 { color: #d75fff; }
    .ansi38-202 { color: #ff5f00; }
    .inv38-202 { background: #ff5f00; }
    .ansi48-202 { background: #ff5f00; }
    .inv48-202 { color: #ff5f00; }
    .ansi38-203 { color: #ff5f5f; }
    .inv38-203 { background: #ff5f5f; }
    .ansi48-203 { background: #ff5f5f; }
    .inv48-203 { color: #ff5f5f; }
    .ansi38-204 { color: #ff5f87; }
    .inv38-204 { background: #ff5f87; }
    .ansi48-204 { background: #ff5f87; }
    .inv48-204 { color: #ff5f87; }
    .ansi38-205 { color: #ff5faf; }
    .inv38-205 { background: #ff5faf; }
    .ansi48-205 { background: #ff5faf; }
    .inv48-205 { color: #ff5faf; }
    .ansi38-206 { color: #ff5fd7; }
    .inv38-206 { background: #ff5fd7; }
    .ansi48-206 { background: #ff5fd7; }
    .inv48-206 { color: #ff5fd7; }
    .ansi38-207 { color: #ff5fff; }
    .inv38-207 { background: #ff5fff; }
    .ansi48-207 { background: #ff5fff; }
    .inv48-207 { color: #ff5fff; }
    .ansi38-28 { color: #008700; }
    .inv38-28 { background: #008700; }
    .ansi48-28 { background: #008700; }
    .inv48-28 { color: #008700; }
    .ansi38-29 { color: #00875f; }
    .inv38-29 { background: #00875f; }
    .ansi48-29 { background: #00875f; }
    .inv48-29 { color: #00875f; }
    .ansi38-30 { color: #008787; }
    .inv38-30 { background: #008787; }
    .ansi48-30 { background: #008787; }
    .inv48-30 { color: #008787; }
    .ansi38-31 { color: #0087af; }
    .inv38-31 { background: #0087af; }
    .ansi48-31 { background: #0087af; }
    .inv48-31 { color: #0087af; }
    .ansi38-32 { color: #0087d7; }
    .inv38-32 { background: #0087d7; }
    .ansi48-32 { background: #0087d7; }
    .inv48-32 { color: #0087d7; }
    .ansi38-33 { color: #0087ff; }
    .inv38-33 { background: #0087ff; }
    .ansi48-33 { background: #0087ff; }
    .inv48-33 { color: #0087ff; }
    .ansi38-64 { color: #5f8700; }
    .inv38-64 { background: #5f8700; }
    .ansi48-64 { background: #5f8700; }
    .inv48-64 { color: #5f8700; }
    .ansi38-65 { color: #5f875f; }
    .inv38-65 { background: #5f875f; }
    .ansi48-65 { background: #5f875f; }
    .inv48-65 { color: #5f875f; }
    .ansi38-66 { color: #5f8787; }
    .inv38-66 { background: #5f8787; }
    .ansi48-66 { background: #5f8787; }
    .inv48-66 { color: #5f8787; }
    .ansi38-67 { color: #5f87af; }
    .inv38-67 { background: #5f87af; }
    .ansi48-67 { background: #5f87af; }
    .inv48-67 { color: #5f87af; }
    .ansi38-68 { color: #5f87d7; }
    .inv38-68 { background: #5f87d7; }
    .ansi48-68 { background: #5f87d7; }
    .inv48-68 { color: #5f87d7; }
    .ansi38-69 { color: #5f87ff; }
    .inv38-69 { background: #5f87ff; }
    .ansi48-69 { background: #5f87ff; }
    .inv48-69 { color: #5f87ff; }
    .ansi38-100 { color: #878700; }
    .inv38-100 { background: #878700; }
    .ansi48-100 { background: #878700; }
    .inv48-100 { color: #878700; }
    .ansi38-101 { color: #87875f; }
    .inv38-101 { background: #87875f; }
    .ansi48-101 { background: #87875f; }
    .inv48-101 { color: #87875f; }
    .ansi38-102 { color: #878787; }
    .inv38-102 { background: #878787; }
    .ansi48-102 { background: #878787; }
    .inv48-102 { color: #878787; }
    .ansi38-103 { color: #8787af; }
    .inv38-103 { background: #8787af; }
    .ansi48-103 { background: #8787af; }
    .inv48-103 { color: #8787af; }
    .ansi38-104 { color: #8787d7; }
    .inv38-104 { background: #8787d7; }
    .ansi48-104 { background: #8787d7; }
    .inv48-104 { color: #8787d7; }
    .ansi38-105 { color: #8787ff; }
    .inv38-105 { background: #8787ff; }
    .ansi48-105 { background: #8787ff; }
    .inv48-105 { color: #8787ff; }
    .ansi38-136 { color: #af8700; }
    .inv38-136 { background: #af8700; }
    .ansi48-136 { background: #af8700; }
    .inv48-136 { color: #af8700; }
    .ansi38-137 { color: #af875f; }
    .inv38-137 { background: #af875f; }
    .ansi48-137 { background: #af875f; }
    .inv48-137 { color: #af875f; }
    .ansi38-138 { color: #af8787; }
    .inv38-138 { background: #af8787; }
    .ansi48-138 { background: #af8787; }
    .inv48-138 { color: #af8787; }
    .ansi38-139 { color: #af87af; }
    .inv38-139 { background: #af87af; }
    .ansi48-139 { background: #af87af; }
    .inv48-139 { color: #af87af; }
    .ansi38-140 { color: #af87d7; }
    .inv38-140 { background: #af87d7; }
    .ansi48-140 { background: #af87d7; }
    .inv48-140 { color: #af87d7; }
    .ansi38-141 { color: #af87ff; }
    .inv38-141 { background: #af87ff; }
    .ansi48-141 { background: #af87ff; }
    .inv48-141 { color: #af87ff; }
    .ansi38-172 { color: #d78700; }
    .inv38-172 { background: #d78700; }
    .ansi48-172 { background: #d78700; }
    .inv48-172 { color: #d78700; }
    .ansi38-173 { color: #d7875f; }
    .inv38-173 { background: #d7875f; }
    .ansi48-173 { background: #d7875f; }
    .inv48-173 { color: #d7875f; }
    .ansi38-174 { color: #d78787; }
    .inv38-174 { background: #d78787; }
    .ansi48-174 { background: #d78787; }
    .inv48-174 { color: #d78787; }
    .ansi38-175 { color: #d787af; }
    .inv38-175 { background: #d787af; }
    .ansi48-175 { background: #d787af; }
    .inv48-175 { color: #d787af; }
    .ansi38-176 { color: #d787d7; }
    .inv38-176 { background: #d787d7; }
    .ansi48-176 { background: #d787d7; }
    .inv48-176 { color: #d787d7; }
    .ansi38-177 { color: #d787ff; }
    .inv38-177 { background: #d787ff; }
    .ansi48-177 { background: #d787ff; }
    .inv48-177 { color: #d787ff; }
    .ansi38-208 { color: #ff8700; }
    .inv38-208 { background: #ff8700; }
    .ansi48-208 { background: #ff8700; }
    .inv48-208 { color: #ff8700; }
    .ansi38-209 { color: #ff875f; }
    .inv38-209 { background: #ff875f; }
    .ansi48-209 { background: #ff875f; }
    .inv48-209 { color: #ff875f; }
    .ansi38-210 { color: #ff8787; }
    .inv38-210 { background: #ff8787; }
    .ansi48-210 { background: #ff8787; }
    .inv48-210 { color: #ff8787; }
    .ansi38-211 { color: #ff87af; }
    .inv38-211 { background: #ff87af; }
    .ansi48-211 { background: #ff87af; }
    .inv48-211 { color: #ff87af; }
    .ansi38-212 { color: #ff87d7; }
    .inv38-212 { background: #ff87d7; }
    .ansi48-212 { background: #ff87d7; }
    .inv48-212 { color: #ff87d7; }
    .ansi38-213 { color: #ff87ff; }
    .inv38-213 { background: #ff87ff; }
    .ansi48-213 { background: #ff87ff; }
    .inv48-213 { color: #ff87ff; }
    .ansi38-34 { color: #00af00; }
    .inv38-34 { background: #00af00; }
    .ansi48-34 { background: #00af00; }
    .inv48-34 { color: #00af00; }
    .ansi38-35 { color: #00af5f; }
    .inv38-35 { background: #00af5f; }
    .ansi48-35 { background: #00af5f; }
    .inv48-35 { color: #00af5f; }
    .ansi38-36 { color: #00af87; }
    .inv38-36 { background: #00af87; }
    .ansi48-36 { background: #00af87; }
    .inv48-36 { color: #00af87; }
    .ansi38-37 { color: #00afaf; }
    .inv38-37 { background: #00afaf; }
    .ansi48-37 { background: #00afaf; }
    .inv48-37 { color: #00afaf; }
    .ansi38-38 { color: #00afd7; }
    .inv38-38 { background: #00afd7; }
    .ansi48-38 { background: #00afd7; }
    .inv48-38 { color: #00afd7; }
    .ansi38-39 { color: #00afff; }
    .inv38-39 { background: #00afff; }
    .ansi48-39 { background: #00afff; }
    .inv48-39 { color: #00afff; }
    .ansi38-70 { color: #5faf00; }
    .inv38-70 { background: #5faf00; }
    .ansi48-70 { background: #5faf00; }
    .inv48-70 { color: #5faf00; }
    .ansi38-71 { color: #5faf5f; }
    .inv38-71 { background: #5faf5f; }
    .ansi48-71 { background: #5faf5f; }
    .inv48-71 { color: #5faf5f; }
    .ansi38-72 { color: #5faf87; }
    .inv38-72 { background: #5faf87; }
    .ansi48-72 { background: #5faf87; }
    .inv48-72 { color: #5faf87; }
    .ansi38-73 { color: #5fafaf; }
    .inv38-73 { background: #5fafaf; }
    .ansi48-73 { background: #5fafaf; }
    .inv48-73 { color: #5fafaf; }
    .ansi38-74 { color: #5fafd7; }
    .inv38-74 { background: #5fafd7; }
    .ansi48-74 { background: #5fafd7; }
    .inv48-74 { color: #5fafd7; }
    .ansi38-75 { color: #5fafff; }
    .inv38-75 { background: #5fafff; }
    .ansi48-75 { background: #5fafff; }
    .inv48-75 { color: #5fafff; }
    .ansi38-106 { color: #87af00; }
    .inv38-106 { background: #87af00; }
    .ansi48-106 { background: #87af00; }
    .inv48-106 { color: #87af00; }
    .ansi38-107 { color: #87af5f; }
    .inv38-107 { background: #87af5f; }
    .ansi48-107 { background: #87af5f; }
    .inv48-107 { color: #87af5f; }
    .ansi38-108 { color: #87af87; }
    .inv38-108 { background: #87af87; }
    .ansi48-108 { background: #87af87; }
    .inv48-108 { color: #87af87; }
    .ansi38-109 { color: #87afaf; }
    .inv38-109 { background: #87afaf; }
    .ansi48-109 { background: #87afaf; }
    .inv48-109 { color: #87afaf; }
    .ansi38-110 { color: #87afd7; }
    .inv38-110 { background: #87afd7; }
    .ansi48-110 { background: #87afd7; }
    .inv48-110 { color: #87afd7; }
    .ansi38-111 { color: #87afff; }
    .inv38-111 { background: #87afff; }
    .ansi48-111 { background: #87afff; }
    .inv48-111 { color: #87afff; }
    .ansi38-142 { color: #afaf00; }
    .inv38-142 { background: #afaf00; }
    .ansi48-142 { background: #afaf00; }
    .inv48-142 { color: #afaf00; }
    .ansi38-143 { color: #afaf5f; }
    .inv38-143 { background: #afaf5f; }
    .ansi48-143 { background: #afaf5f; }
    .inv48-143 { color: #afaf5f; }
    .ansi38-144 { color: #afaf87; }
    .inv38-144 { background: #afaf87; }
    .ansi48-144 { background: #afaf87; }
    .inv48-144 { color: #afaf87; }
    .ansi38-145 { color: #afafaf; }
    .inv38-145 { background: #afafaf; }
    .ansi48-145 { background: #afafaf; }
    .inv48-145 { color: #afafaf; }
    .ansi38-146 { color: #afafd7; }
    .inv38-146 { background: #afafd7; }
    .ansi48-146 { background: #afafd7; }
    .inv48-146 { color: #afafd7; }
    .ansi38-147 { color: #afafff; }
    .inv38-147 { background: #afafff; }
    .ansi48-147 { background: #afafff; }
    .inv48-147 { color: #afafff; }
    .ansi38-178 { color: #d7af00; }
    .inv38-178 { background: #d7af00; }
    .ansi48-178 { background: #d7af00; }
    .inv48-178 { color: #d7af00; }
    .ansi38-179 { color: #d7af5f; }
    .inv38-179 { background: #d7af5f; }
    .ansi48-179 { background: #d7af5f; }
    .inv48-179 { color: #d7af5f; }
    .ansi38-180 { color: #d7af87; }
    .inv38-180 { background: #d7af87; }
    .ansi48-180 { background: #d7af87; }
    .inv48-180 { color: #d7af87; }
    .ansi38-181 { color: #d7afaf; }
    .inv38-181 { background: #d7afaf; }
    .ansi48-181 { background: #d7afaf; }
    .inv48-181 { color: #d7afaf; }
    .ansi38-182 { color: #d7afd7; }
    .inv38-182 { background: #d7afd7; }
    .ansi48-182 { background: #d7afd7; }
    .inv48-182 { color: #d7afd7; }
    .ansi38-183 { color: #d7afff; }
    .inv38-183 { background: #d7afff; }
    .ansi48-183 { background: #d7afff; }
    .inv48-183 { color: #d7afff; }
    .ansi38-214 { color: #ffaf00; }
    .inv38-214 { background: #ffaf00; }
    .ansi48-214 { background: #ffaf00; }
    .inv48-214 { color: #ffaf00; }
    .ansi38-215 { color: #ffaf5f; }
    .inv38-215 { background: #ffaf5f; }
    .ansi48-215 { background: #ffaf5f; }
    .inv48-215 { color: #ffaf5f; }
    .ansi38-216 { color: #ffaf87; }
    .inv38-216 { background: #ffaf87; }
    .ansi48-216 { background: #ffaf87; }
    .inv48-216 { color: #ffaf87; }
    .ansi38-217 { color: #ffafaf; }
    .inv38-217 { background: #ffafaf; }
    .ansi48-217 { background: #ffafaf; }
    .inv48-217 { color: #ffafaf; }
    .ansi38-218 { color: #ffafd7; }
    .inv38-218 { background: #ffafd7; }
    .ansi48-218 { background: #ffafd7; }
    .inv48-218 { color: #ffafd7; }
    .ansi38-219 { color: #ffafff; }
    .inv38-219 { background: #ffafff; }
    .ansi48-219 { background: #ffafff; }
    .inv48-219 { color: #ffafff; }
    .ansi38-40 { color: #00d700; }
    .inv38-40 { background: #00d700; }
    .ansi48-40 { background: #00d700; }
    .inv48-40 { color: #00d700; }
    .ansi38-41 { color: #00d75f; }
    .inv38-41 { background: #00d75f; }
    .ansi48-41 { background: #00d75f; }
    .inv48-41 { color: #00d75f; }
    .ansi38-42 { color: #00d787; }
    .inv38-42 { background: #00d787; }
    .ansi48-42 { background: #00d787; }
    .inv48-42 { color: #00d787; }
    .ansi38-43 { color: #00d7af; }
    .inv38-43 { background: #00d7af; }
    .ansi48-43 { background: #00d7af; }
    .inv48-43 { color: #00d7af; }
    .ansi38-44 { color: #00d7d7; }
    .inv38-44 { background: #00d7d7; }
    .ansi48-44 { background: #00d7d7; }
    .inv48-44 { color: #00d7d7; }
    .ansi38-45 { color: #00d7ff; }
    .inv38-45 { background: #00d7ff; }
    .ansi48-45 { background: #00d7ff; }
    .inv48-45 { color: #00d7ff; }
    .ansi38-76 { color: #5fd700; }
    .inv38-76 { background: #5fd700; }
    .ansi48-76 { background: #5fd700; }
    .inv48-76 { color: #5fd700; }
    .ansi38-77 { color: #5fd75f; }
    .inv38-77 { background: #5fd75f; }
    .ansi48-77 { background: #5fd75f; }
    .inv48-77 { color: #5fd75f; }
    .ansi38-78 { color: #5fd787; }
    .inv38-78 { background: #5fd787; }
    .ansi48-78 { background: #5fd787; }
    .inv48-78 { color: #5fd787; }
    .ansi38-79 { color: #5fd7af; }
    .inv38-79 { background: #5fd7af; }
    .ansi48-79 { background: #5fd7af; }
    .inv48-79 { color: #5fd7af; }
    .ansi38-80 { color: #5fd7d7; }
    .inv38-80 { background: #5fd7d7; }
    .ansi48-80 { background: #5fd7d7; }
    .inv48-80 { color: #5fd7d7; }
    .ansi38-81 { color: #5fd7ff; }
    .inv38-81 { background: #5fd7ff; }
    .ansi48-81 { background: #5fd7ff; }
    .inv48-81 { color: #5fd7ff; }
    .ansi38-112 { color: #87d700; }
    .inv38-112 { background: #87d700; }
    .ansi48-112 { background: #87d700; }
    .inv48-112 { color: #87d700; }
    .ansi38-113 { color: #87d75f; }
    .inv38-113 { background: #87d75f; }
    .ansi48-113 { background: #87d75f; }
    .inv48-113 { color: #87d75f; }
    .ansi38-114 { color: #87d787; }
    .inv38-114 { background: #87d787; }
    .ansi48-114 { background: #87d787; }
    .inv48-114 { color: #87d787; }
    .ansi38-115 { color: #87d7af; }
    .inv38-115 { background: #87d7af; }
    .ansi48-115 { background: #87d7af; }
    .inv48-115 { color: #87d7af; }
    .ansi38-116 { color: #87d7d7; }
    .inv38-116 { background: #87d7d7; }
    .ansi48-116 { background: #87d7d7; }
    .inv48-116 { color: #87d7d7; }
    .ansi38-117 { color: #87d7ff; }
    .inv38-117 { background: #87d7ff; }
    .ansi48-117 { background: #87d7ff; }
    .inv48-117 { color: #87d7ff; }
    .ansi38-148 { color: #afd700; }
    .inv38-148 { background: #afd700; }
    .ansi48-148 { background: #afd700; }
    .inv48-148 { color: #afd700; }
    .ansi38-149 { color: #afd75f; }
    .inv38-149 { background: #afd75f; }
    .ansi48-149 { background: #afd75f; }
    .inv48-149 { color: #afd75f; }
    .ansi38-150 { color: #afd787; }
    .inv38-150 { background: #afd787; }
    .ansi48-150 { background: #afd787; }
    .inv48-150 { color: #afd787; }
    .ansi38-151 { color: #afd7af; }
    .inv38-151 { background: #afd7af; }
    .ansi48-151 { background: #afd7af; }
    .inv48-151 { color: #afd7af; }
    .ansi38-152 { color: #afd7d7; }
    .inv38-152 { background: #afd7d7; }
    .ansi48-152 { background: #afd7d7; }
    .inv48-152 { color: #afd7d7; }
    .ansi38-153 { color: #afd7ff; }
    .inv38-153 { background: #afd7ff; }
    .ansi48-153 { background: #afd7ff; }
    .inv48-153 { color: #afd7ff; }
    .ansi38-184 { color: #d7d700; }
    .inv38-184 { background: #d7d700; }
    .ansi48-184 { background: #d7d700; }
    .inv48-184 { color: #d7d700; }
    .ansi38-185 { color: #d7d75f; }
    .inv38-185 { background: #d7d75f; }
    .ansi48-185 { background: #d7d75f; }
    .inv48-185 { color: #d7d75f; }
    .ansi38-186 { color: #d7d787; }
    .inv38-186 { background: #d7d787; }
    .ansi48-186 { background: #d7d787; }
    .inv48-186 { color: #d7d787; }
    .ansi38-187 { color: #d7d7af; }
    .inv38-187 { background: #d7d7af; }
    .ansi48-187 { background: #d7d7af; }
    .inv48-187 { color: #d7d7af; }
    .ansi38-188 { color: #d7d7d7; }
    .inv38-188 { background: #d7d7d7; }
    .ansi48-188 { background: #d7d7d7; }
    .inv48-188 { color: #d7d7d7; }
    .ansi38-189 { color: #d7d7ff; }
    .inv38-189 { background: #d7d7ff; }
    .ansi48-189 { background: #d7d7ff; }
    .inv48-189 { color: #d7d7ff; }
    .ansi38-220 { color: #ffd700; }
    .inv38-220 { background: #ffd700; }
    .ansi48-220 { background: #ffd700; }
    .inv48-220 { color: #ffd700; }
    .ansi38-221 { color: #ffd75f; }
    .inv38-221 { background: #ffd75f; }
    .ansi48-221 { background: #ffd75f; }
    .inv48-221 { color: #ffd75f; }
    .ansi38-222 { color: #ffd787; }
    .inv38-222 { background: #ffd787; }
    .ansi48-222 { background: #ffd787; }
    .inv48-222 { color: #ffd787; }
    .ansi38-223 { color: #ffd7af; }
    .inv38-223 { background: #ffd7af; }
    .ansi48-223 { background: #ffd7af; }
    .inv48-223 { color: #ffd7af; }
    .ansi38-224 { color: #ffd7d7; }
    .inv38-224 { background: #ffd7d7; }
    .ansi48-224 { background: #ffd7d7; }
    .inv48-224 { color: #ffd7d7; }
    .ansi38-225 { color: #ffd7ff; }
    .inv38-225 { background: #ffd7ff; }
    .ansi48-225 { background: #ffd7ff; }
    .inv48-225 { color: #ffd7ff; }
    .ansi38-46 { color: #00ff00; }
    .inv38-46 { background: #00ff00; }
    .ansi48-46 { background: #00ff00; }
    .inv48-46 { color: #00ff00; }
    .ansi38-47 { color: #00ff5f; }
    .inv38-47 { background: #00ff5f; }
    .ansi48-47 { background: #00ff5f; }
    .inv48-47 { color: #00ff5f; }
    .ansi38-48 { color: #00ff87; }
    .inv38-48 { background: #00ff87; }
    .ansi48-48 { background: #00ff87; }
    .inv48-48 { color: #00ff87; }
    .ansi38-49 { color: #00ffaf; }
    .inv38-49 { background: #00ffaf; }
    .ansi48-49 { background: #00ffaf; }
    .inv48-49 { color: #00ffaf; }
    .ansi38-50 { color: #00ffd7; }
    .inv38-50 { background: #00ffd7; }
    .ansi48-50 { background: #00ffd7; }
    .inv48-50 { color: #00ffd7; }
    .ansi38-51 { color: #00ffff; }
    .inv38-51 { background: #00ffff; }
    .ansi48-51 { background: #00ffff; }
    .inv48-51 { color: #00ffff; }
    .ansi38-82 { color: #5fff00; }
    .inv38-82 { background: #5fff00; }
    .ansi48-82 { background: #5fff00; }
    .inv48-82 { color: #5fff00; }
    .ansi38-83 { color: #5fff5f; }
    .inv38-83 { background: #5fff5f; }
    .ansi48-83 { background: #5fff5f; }
    .inv48-83 { color: #5fff5f; }
    .ansi38-84 { color: #5fff87; }
    .inv38-84 { background: #5fff87; }
    .ansi48-84 { background: #5fff87; }
    .inv48-84 { color: #5fff87; }
    .ansi38-85 { color: #5fffaf; }
    .inv38-85 { background: #5fffaf; }
    .ansi48-85 { background: #5fffaf; }
    .inv48-85 { color: #5fffaf; }
    .ansi38-86 { color: #5fffd7; }
    .inv38-86 { background: #5fffd7; }
    .ansi48-86 { background: #5fffd7; }
    .inv48-86 { color: #5fffd7; }
    .ansi38-87 { color: #5fffff; }
    .inv38-87 { background: #5fffff; }
    .ansi48-87 { background: #5fffff; }
    .inv48-87 { color: #5fffff; }
    .ansi38-118 { color: #87ff00; }
    .inv38-118 { background: #87ff00; }
    .ansi48-118 { background: #87ff00; }
    .inv48-118 { color: #87ff00; }
    .ansi38-119 { color: #87ff5f; }
    .inv38-119 { background: #87ff5f; }
    .ansi48-119 { background: #87ff5f; }
    .inv48-119 { color: #87ff5f; }
    .ansi38-120 { color: #87ff87; }
    .inv38-120 { background: #87ff87; }
    .ansi48-120 { background: #87ff87; }
    .inv48-120 { color: #87ff87; }
    .ansi38-121 { color: #87ffaf; }
    .inv38-121 { background: #87ffaf; }
    .ansi48-121 { background: #87ffaf; }
    .inv48-121 { color: #87ffaf; }
    .ansi38-122 { color: #87ffd7; }
    .inv38-122 { background: #87ffd7; }
    .ansi48-122 { background: #87ffd7; }
    .inv48-122 { color: #87ffd7; }
    .ansi38-123 { color: #87ffff; }
    .inv38-123 { background: #87ffff; }
    .ansi48-123 { background: #87ffff; }
    .inv48-123 { color: #87ffff; }
    .ansi38-154 { color: #afff00; }
    .inv38-154 { background: #afff00; }
    .ansi48-154 { background: #afff00; }
    .inv48-154 { color: #afff00; }
    .ansi38-155 { color: #afff5f; }
    .inv38-155 { background: #afff5f; }
    .ansi48-155 { background: #afff5f; }
    .inv48-155 { color: #afff5f; }
    .ansi38-156 { color: #afff87; }
    .inv38-156 { background: #afff87; }
    .ansi48-156 { background: #afff87; }
    .inv48-156 { color: #afff87; }
    .ansi38-157 { color: #afffaf; }
    .inv38-157 { background: #afffaf; }
    .ansi48-157 { background: #afffaf; }
    .inv48-157 { color: #afffaf; }
    .ansi38-158 { color: #afffd7; }
    .inv38-158 { background: #afffd7; }
    .ansi48-158 { background: #afffd7; }
    .inv48-158 { color: #afffd7; }
    .ansi38-159 { color: #afffff; }
    .inv38-159 { background: #afffff; }
    .ansi48-159 { background: #afffff; }
    .inv48-159 { color: #afffff; }
    .ansi38-190 { color: #d7ff00; }
    .inv38-190 { background: #d7ff00; }
    .ansi48-190 { background: #d7ff00; }
    .inv48-190 { color: #d7ff00; }
    .ansi38-191 { color: #d7ff5f; }
    .inv38-191 { background: #d7ff5f; }
    .ansi48-191 { background: #d7ff5f; }
    .inv48-191 { color: #d7ff5f; }
    .ansi38-192 { color: #d7ff87; }
    .inv38-192 { background: #d7ff87; }
    .ansi48-192 { background: #d7ff87; }
    .inv48-192 { color: #d7ff87; }
    .ansi38-193 { color: #d7ffaf; }
    .inv38-193 { background: #d7ffaf; }
    .ansi48-193 { background: #d7ffaf; }
    .inv48-193 { color: #d7ffaf; }
    .ansi38-194 { color: #d7ffd7; }
    .inv38-194 { background: #d7ffd7; }
    .ansi48-194 { background: #d7ffd7; }
    .inv48-194 { color: #d7ffd7; }
    .ansi38-195 { color: #d7ffff; }
    .inv38-195 { background: #d7ffff; }
    .ansi48-195 { background: #d7ffff; }
    .inv48-195 { color: #d7ffff; }
    .ansi38-226 { color: #ffff00; }
    .inv38-226 { background: #ffff00; }
    .ansi48-226 { background: #ffff00; }
    .inv48-226 { color: #ffff00; }
    .ansi38-227 { color: #ffff5f; }
    .inv38-227 { background: #ffff5f; }
    .ansi48-227 { background: #ffff5f; }
    .inv48-227 { color: #ffff5f; }
    .ansi38-228 { color: #ffff87; }
    .inv38-228 { background: #ffff87; }
    .ansi48-228 { background: #ffff87; }
    .inv48-228 { color: #ffff87; }
    .ansi38-229 { color: #ffffaf; }
    .inv38-229 { background: #ffffaf; }
    .ansi48-229 { background: #ffffaf; }
    .inv48-229 { color: #ffffaf; }
    .ansi38-230 { color: #ffffd7; }
    .inv38-230 { background: #ffffd7; }
    .ansi48-230 { background: #ffffd7; }
    .inv48-230 { color: #ffffd7; }
    .ansi38-231 { color: #ffffff; }
    .inv38-231 { background: #ffffff; }
    .ansi48-231 { background: #ffffff; }
    .inv48-231 { color: #ffffff; }
    .ansi38-232 { color: #080808; }
    .inv38-232 { background: #080808; }
    .ansi48-232 { background: #080808; }
    .inv48-232 { color: #080808; }
    .ansi38-233 { color: #121212; }
    .inv38-233 { background: #121212; }
    .ansi48-233 { background: #121212; }
    .inv48-233 { color: #121212; }
    .ansi38-234 { color: #1c1c1c; }
    .inv38-234 { background: #1c1c1c; }
    .ansi48-234 { background: #1c1c1c; }
    .inv48-234 { color: #1c1c1c; }
    .ansi38-235 { color: #262626; }
    .inv38-235 { background: #262626; }
    .ansi48-235 { background: #262626; }
    .inv48-235 { color: #262626; }
    .ansi38-236 { color: #303030; }
    .inv38-236 { background: #303030; }
    .ansi48-236 { background: #303030; }
    .inv48-236 { color: #303030; }
    .ansi38-237 { color: #3a3a3a; }
    .inv38-237 { background: #3a3a3a; }
    .ansi48-237 { background: #3a3a3a; }
    .inv48-237 { color: #3a3a3a; }
    .ansi38-238 { color: #444444; }
    .inv38-238 { background: #444444; }
    .ansi48-238 { background: #444444; }
    .inv48-238 { color: #444444; }
    .ansi38-239 { color: #4e4e4e; }
    .inv38-239 { background: #4e4e4e; }
    .ansi48-239 { background: #4e4e4e; }
    .inv48-239 { color: #4e4e4e; }
    .ansi38-240 { color: #585858; }
    .inv38-240 { background: #585858; }
    .ansi48-240 { background: #585858; }
    .inv48-240 { color: #585858; }
    .ansi38-241 { color: #626262; }
    .inv38-241 { background: #626262; }
    .ansi48-241 { background: #626262; }
    .inv48-241 { color: #626262; }
    .ansi38-242 { color: #6c6c6c; }
    .inv38-242 { background: #6c6c6c; }
    .ansi48-242 { background: #6c6c6c; }
    .inv48-242 { color: #6c6c6c; }
    .ansi38-243 { color: #767676; }
    .inv38-243 { background: #767676; }
    .ansi48-243 { background: #767676; }
    .inv48-243 { color: #767676; }
    .ansi38-244 { color: #808080; }
    .inv38-244 { background: #808080; }
    .ansi48-244 { background: #808080; }
    .inv48-244 { color: #808080; }
    .ansi38-245 { color: #8a8a8a; }
    .inv38-245 { background: #8a8a8a; }
    .ansi48-245 { background: #8a8a8a; }
    .inv48-245 { color: #8a8a8a; }
    .ansi38-246 { color: #949494; }
    .inv38-246 { background: #949494; }
    .ansi48-246 { background: #949494; }
    .inv48-246 { color: #949494; }
    .ansi38-247 { color: #9e9e9e; }
    .inv38-247 { background: #9e9e9e; }
    .ansi48-247 { background: #9e9e9e; }
    .inv48-247 { color: #9e9e9e; }
    .ansi38-248 { color: #a8a8a8; }
    .inv38-248 { background: #a8a8a8; }
    .ansi48-248 { background: #a8a8a8; }
    .inv48-248 { color: #a8a8a8; }
    .ansi38-249 { color: #b2b2b2; }
    .inv38-249 { background: #b2b2b2; }
    .ansi48-249 { background: #b2b2b2; }
    .inv48-249 { color: #b2b2b2; }
    .ansi38-250 { color: #bcbcbc; }
    .inv38-250 { background: #bcbcbc; }
    .ansi48-250 { background: #bcbcbc; }
    .inv48-250 { color: #bcbcbc; }
    .ansi38-251 { color: #c6c6c6; }
    .inv38-251 { background: #c6c6c6; }
    .ansi48-251 { background: #c6c6c6; }
    .inv48-251 { color: #c6c6c6; }
    .ansi38-252 { color: #d0d0d0; }
    .inv38-252 { background: #d0d0d0; }
    .ansi48-252 { background: #d0d0d0; }
    .inv48-252 { color: #d0d0d0; }
    .ansi38-253 { color: #dadada; }
    .inv38-253 { background: #dadada; }
    .ansi48-253 { background: #dadada; }
    .inv48-253 { color: #dadada; }
    .ansi38-254 { color: #e4e4e4; }
    .inv38-254 { background: #e4e4e4; }
    .ansi48-254 { background: #e4e4e4; }
    .inv48-254 { color: #e4e4e4; }
    .ansi38-255 { color: #eeeeee; }
    .inv38-255 { background: #eeeeee; }
    .ansi48-255 { background: #eeeeee; }
    .inv48-255 { color: #eeeeee; }
    |]
