{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE StandaloneKindSignatures #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

-- | This module corresponds to "Control.Concurrent.MVar" in the @base@ package.
--
-- This module can be used as a drop-in replacement for
-- "Control.Concurrent.Class.MonadMVar.Strict", but not the other way around.
module Control.Concurrent.Class.MonadMVar.Strict.Checked
  ( -- * StrictMVar
    LazyMVar
  , StrictMVar
  , castStrictMVar
  , fromLazyMVar
  , isEmptyMVar
  , modifyMVar
  , modifyMVarMasked
  , modifyMVarMasked_
  , modifyMVar_
  , newEmptyMVar
  , newEmptyMVarWithInvariant
  , newMVar
  , newMVarWithInvariant
  , putMVar
  , readMVar
  , swapMVar
  , takeMVar
  , toLazyMVar
  , tryPutMVar
  , tryReadMVar
  , tryTakeMVar
  , unsafeToUncheckedStrictMVar
  , withMVar
  , withMVarMasked

    -- * Invariant
  , checkInvariant

    -- * Re-exports
  , MonadMVar
  ) where

import Control.Concurrent.Class.MonadMVar.Strict (LazyMVar, MonadMVar)
import Control.Concurrent.Class.MonadMVar.Strict qualified as Strict
import Data.Kind (Type)
import GHC.Stack (HasCallStack)

{-------------------------------------------------------------------------------
  StrictMVar
-------------------------------------------------------------------------------}

-- | A strict MVar with invariant checking.
--
-- There is a weaker invariant for a 'StrictMVar' than for a 'StrictTVar':
-- although all functions that modify the 'StrictMVar' check the invariant, we
-- do /not/ guarantee that the value inside the 'StrictMVar' always satisfies
-- the invariant. Instead, we /do/ guarantee that if the 'StrictMVar' is updated
-- with a value that does not satisfy the invariant, an exception is thrown. The
-- reason for this weaker guarantee is that leaving an 'MVar' empty can lead to
-- very hard to debug "blocked indefinitely" problems.
type StrictMVar :: (Type -> Type) -> Type -> Type
#if CHECK_MVAR_INVARIANTS
data StrictMVar m a = StrictMVar {
    -- | The invariant that is checked whenever the 'StrictMVar' is updated.
    invariant :: !(a -> Maybe String)
  , mvar      :: !(Strict.StrictMVar m a)
  }
#else
newtype StrictMVar m a = StrictMVar {
    mvar :: Strict.StrictMVar m a
  }
#endif

castStrictMVar ::
  LazyMVar m ~ LazyMVar n =>
  StrictMVar m a -> StrictMVar n a
castStrictMVar v = mkStrictMVar (getInvariant v) (Strict.castStrictMVar $ mvar v)

-- | Get the underlying @MVar@
--
-- Since we obviously can not guarantee that updates to this 'LazyMVar' will be
-- strict, this should be used with caution.
--
-- Similarly, we can not guarantee that updates to this 'LazyMVar' do not break
-- the original invariant that the 'StrictMVar' held.
toLazyMVar :: StrictMVar m a -> LazyMVar m a
toLazyMVar = Strict.toLazyMVar . mvar

-- | Create a 'StrictMVar' from a 'LazyMVar'
--
-- It is not guaranteed that the 'LazyMVar' contains a value that is in WHNF, so
-- there is no guarantee that the resulting 'StrictMVar' contains a value that
-- is in WHNF. This should be used with caution.
--
-- The resulting 'StrictMVar' has a trivial invariant.
fromLazyMVar :: LazyMVar m a -> StrictMVar m a
fromLazyMVar = mkStrictMVar (const Nothing) . Strict.fromLazyMVar

-- | Create an unchecked reference to the given checked 'StrictMVar'.
--
-- Note that the invariant is only guaranteed when modifying the checked MVar.
-- Any modification to the unchecked reference might break the invariants.
unsafeToUncheckedStrictMVar :: StrictMVar m a -> Strict.StrictMVar m a
unsafeToUncheckedStrictMVar = mvar

newEmptyMVar :: MonadMVar m => m (StrictMVar m a)
newEmptyMVar = mkStrictMVar (const Nothing) <$> Strict.newEmptyMVar

newEmptyMVarWithInvariant ::
  MonadMVar m =>
  (a -> Maybe String) ->
  m (StrictMVar m a)
newEmptyMVarWithInvariant inv = mkStrictMVar inv <$> Strict.newEmptyMVar

newMVar :: MonadMVar m => a -> m (StrictMVar m a)
newMVar a = mkStrictMVar (const Nothing) <$> Strict.newMVar a

-- | Create a 'StrictMVar' with an invariant.
--
-- Contrary to functions that modify a 'StrictMVar', this function checks the
-- invariant /before/ putting the value in a new 'StrictMVar'.
newMVarWithInvariant ::
  (HasCallStack, MonadMVar m) =>
  (a -> Maybe String) ->
  a ->
  m (StrictMVar m a)
newMVarWithInvariant inv !a =
  checkInvariant (inv a) $
    mkStrictMVar inv <$> Strict.newMVar a

takeMVar :: MonadMVar m => StrictMVar m a -> m a
takeMVar = Strict.takeMVar . mvar

putMVar :: (HasCallStack, MonadMVar m) => StrictMVar m a -> a -> m ()
putMVar v a = do
  Strict.putMVar (mvar v) a
  checkInvariant (getInvariant v a) $ pure ()

readMVar :: MonadMVar m => StrictMVar m a -> m a
readMVar v = Strict.readMVar (mvar v)

swapMVar :: (HasCallStack, MonadMVar m) => StrictMVar m a -> a -> m a
swapMVar v a = do
  oldValue <- Strict.swapMVar (mvar v) a
  checkInvariant (getInvariant v a) $ pure oldValue

tryTakeMVar :: MonadMVar m => StrictMVar m a -> m (Maybe a)
tryTakeMVar v = Strict.tryTakeMVar (mvar v)

tryPutMVar :: (HasCallStack, MonadMVar m) => StrictMVar m a -> a -> m Bool
tryPutMVar v a = do
  didPut <- Strict.tryPutMVar (mvar v) a
  checkInvariant (getInvariant v a) $ pure didPut

isEmptyMVar :: MonadMVar m => StrictMVar m a -> m Bool
isEmptyMVar v = Strict.isEmptyMVar (mvar v)

withMVar :: MonadMVar m => StrictMVar m a -> (a -> m b) -> m b
withMVar v = Strict.withMVar (mvar v)

withMVarMasked :: MonadMVar m => StrictMVar m a -> (a -> m b) -> m b
withMVarMasked v = Strict.withMVarMasked (mvar v)

-- | 'modifyMVar_' is defined in terms of 'modifyMVar'.
modifyMVar_ ::
  (HasCallStack, MonadMVar m) =>
  StrictMVar m a ->
  (a -> m a) ->
  m ()
modifyMVar_ v io = modifyMVar v io'
 where
  io' a = (,()) <$> io a

modifyMVar ::
  (HasCallStack, MonadMVar m) =>
  StrictMVar m a ->
  (a -> m (a, b)) ->
  m b
modifyMVar v io = do
  (a', b) <- Strict.modifyMVar (mvar v) io'
  checkInvariant (getInvariant v a') $ pure b
 where
  io' a = do
    (a', b) <- io a
    -- Returning @a'@ along with @b@ allows us to check the invariant /after/
    -- filling in the MVar.
    pure (a', (a', b))

-- | 'modifyMVarMasked_' is defined in terms of 'modifyMVarMasked'.
modifyMVarMasked_ ::
  (HasCallStack, MonadMVar m) =>
  StrictMVar m a ->
  (a -> m a) ->
  m ()
modifyMVarMasked_ v io = modifyMVarMasked v io'
 where
  io' a = (,()) <$> io a

modifyMVarMasked ::
  (HasCallStack, MonadMVar m) =>
  StrictMVar m a ->
  (a -> m (a, b)) ->
  m b
modifyMVarMasked v io = do
  (a', b) <- Strict.modifyMVarMasked (mvar v) io'
  checkInvariant (getInvariant v a') $ pure b
 where
  io' a = do
    (a', b) <- io a
    -- Returning @a'@ along with @b@ allows us to check the invariant /after/
    -- filling in the MVar.
    pure (a', (a', b))

tryReadMVar :: MonadMVar m => StrictMVar m a -> m (Maybe a)
tryReadMVar v = Strict.tryReadMVar (mvar v)

--
-- Dealing with invariants
--

-- | Check invariant (if enabled) before continuing
--
-- @checkInvariant mErr x@ is equal to @x@ if @mErr == Nothing@, and throws
-- an error @err@ if @mErr == Just err@.
--
-- This is exported so that other code that wants to conditionally check
-- invariants can reuse the same logic, rather than having to introduce new
-- per-package flags.
checkInvariant :: HasCallStack => Maybe String -> a -> a
getInvariant :: StrictMVar m a -> a -> Maybe String
mkStrictMVar :: (a -> Maybe String) -> Strict.StrictMVar m a -> StrictMVar m a

#if CHECK_MVAR_INVARIANTS
checkInvariant Nothing    k = k
checkInvariant (Just err) _ = error $ "StrictMVar invariant violation: " ++ err
getInvariant StrictMVar {invariant} = invariant
mkStrictMVar invariant  mvar        = StrictMVar {invariant, mvar}
#else
checkInvariant _err       k  = k
getInvariant _               = const Nothing
mkStrictMVar _invariant mvar = StrictMVar {mvar}
#endif
