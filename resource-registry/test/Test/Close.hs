{-# LANGUAGE ScopedTypeVariables #-}

-- | Closing the registry while one of its threads forks another.
--
-- 'closeRegistry' must cancel every thread of the registry before it marks
-- the registry closed, including a thread forked while it closes. Otherwise
-- that thread can 'allocate' on a closed registry and get
-- 'RegistryClosedException' during a normal shutdown.
--
-- The race needs a particular interleaving, so the test runs in IOSim and
-- explores the thread schedules with IOSimPOR.
module Test.Close (tests) where

import Control.Concurrent.Class.MonadSTM.Strict (atomically, newTVarIO, readTVarIO, writeTVar)
import Control.Monad (void)
import Control.Monad.Class.MonadAsync (async, wait)
import Control.Monad.Class.MonadTest (exploreRaces)
import Control.Monad.Class.MonadThrow (try)
import Control.Monad.IOSim (IOSim, exploreSimTrace, traceResult, withScheduleBound)
import Control.ResourceRegistry
  ( RegistryClosedException
  , allocate
  , closeRegistry
  , forkThread
  , unsafeNewRegistry
  )
import Test.QuickCheck (counterexample, once, property)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.QuickCheck (testProperty)

tests :: TestTree
tests =
  testGroup
    "closeRegistry"
    [ testProperty "a thread forked while closing never sees the registry closed" $
        once $
          -- A small program: explore it thoroughly.
          exploreSimTrace (withScheduleBound 10000) explored $ \_ tr ->
            -- Computing the result forces the trace, which IOSimPOR needs to
            -- find the races.
            case traceResult False tr of
              Right sawClosed ->
                counterexample "the forked thread got RegistryClosedException" $
                  property (not sawClosed)
              Left failure -> counterexample (show failure) False
    ]
 where
  -- Only threads forked after 'exploreRaces' take part in exploration, so the
  -- scenario runs in one.
  explored :: IOSim s Bool
  explored = do
    exploreRaces
    async closeWhileForking >>= wait

-- | The registry's creator closes it while an "acceptor" thread forks a
-- "handler" that allocates a resource. Returns whether the handler got
-- 'RegistryClosedException'.
closeWhileForking :: IOSim s Bool
closeWhileForking = do
  rr <- unsafeNewRegistry
  sawClosed <- newTVarIO False
  _ <- forkThread rr "acceptor" $
    void $
      forkThread rr "handler" $ do
        r <- try (allocate rr (\_ -> pure ()) (\_ -> pure ()))
        case r of
          Left (_ :: RegistryClosedException) -> atomically (writeTVar sawClosed True)
          Right _ -> pure ()
  closeRegistry rr
  readTVarIO sawClosed
