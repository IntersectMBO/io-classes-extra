{-# LANGUAGE ScopedTypeVariables #-}

-- | 'unsafeReleaseAll' from a thread the registry doesn't know.
--
-- Like 'Control.ResourceRegistry.unsafeRelease', it must not insist that the
-- caller is known to the registry. It must release every resource and cancel
-- every thread of the registry.
module Test.Untracked (tests) where

import Control.Concurrent.Class.MonadSTM.Strict
  ( atomically
  , modifyTVar
  , newEmptyTMVarIO
  , newTVarIO
  , putTMVar
  , readTVarIO
  , retry
  , takeTMVar
  , writeTVar
  )
import Control.Exception (SomeException, displayException)
import Control.Monad.Class.MonadFork (forkIO)
import Control.Monad.Class.MonadThrow (finally, try)
import Control.Monad.IOSim (IOSim, runSimOrThrow)
import Control.ResourceRegistry
  ( allocate
  , closeRegistry
  , countResources
  , forkThread
  , unsafeNewRegistry
  , unsafeReleaseAll
  )
import Test.QuickCheck (Property, counterexample, once, property, (.&&.), (===))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.QuickCheck (testProperty)

tests :: TestTree
tests =
  testGroup
    "unsafeReleaseAll"
    [ testProperty "from an untracked thread, releases resources and cancels threads" $
        once (runSimOrThrow fromUntrackedThread)
    ]

-- | A registry with a resource and a thread. A thread forked with 'forkIO',
-- so unknown to the registry, calls 'unsafeReleaseAll'.
fromUntrackedThread :: IOSim s Property
fromUntrackedThread = do
  rr <- unsafeNewRegistry
  freed <- newTVarIO (0 :: Int)
  _ <- allocate rr (\_ -> pure ()) (\_ -> atomically (modifyTVar freed (+ 1)))
  workerEnded <- newTVarIO False
  _ <-
    forkThread rr "worker" $
      (atomically retry :: IOSim s ()) `finally` atomically (writeTVar workerEnded True)
  done <- newEmptyTMVarIO
  _ <- forkIO $ try (unsafeReleaseAll rr) >>= atomically . putTMVar done
  result <- atomically (takeTMVar done)
  left <- countResources rr
  timesFreed <- readTVarIO freed
  ended <- readTVarIO workerEnded
  closeRegistry rr
  pure $
    counterexample
      "unsafeReleaseAll threw"
      ( either
          (\(e :: SomeException) -> counterexample (displayException e) False)
          (const (property True))
          result
      )
      .&&. counterexample "resources left" (left === 0)
      .&&. counterexample "times the resource was freed" (timesFreed === 1)
      .&&. counterexample "the worker thread was not cancelled" ended
