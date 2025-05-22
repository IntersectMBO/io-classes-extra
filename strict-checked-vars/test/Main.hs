module Main where

import Test.Control.Concurrent.Class.MonadMVar.Strict.Checked qualified
import Test.Control.Concurrent.Class.MonadMVar.Strict.Checked.WHNF qualified
import Test.Control.Concurrent.Class.MonadSTM.Strict.TVar.Checked qualified
import Test.Control.Concurrent.Class.MonadSTM.Strict.TVar.Checked.WHNF qualified
import Test.Tasty (defaultMain, testGroup)

main :: IO ()
main =
  defaultMain $
    testGroup
      "strict-checked-vars"
      [ Test.Control.Concurrent.Class.MonadMVar.Strict.Checked.tests
      , Test.Control.Concurrent.Class.MonadMVar.Strict.Checked.WHNF.tests
      , Test.Control.Concurrent.Class.MonadSTM.Strict.TVar.Checked.tests
      , Test.Control.Concurrent.Class.MonadSTM.Strict.TVar.Checked.WHNF.tests
      ]
