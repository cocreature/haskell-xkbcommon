{-# LANGUAGE CPP, ForeignFunctionInterface #-}

module Text.XkbCommon.KeyboardState
   ( KeyboardState, newKeyboardState, updateKeyboardStateKey, updateKeyboardStateMask, getOneKeySym, getStateSyms,
     stateRemoveConsumed,

     stateModNameIsActive, stateModIndexIsActive, stateLedNameIsActive, stateSerializeMods,
   ) where

import Foreign
import Foreign.C
import Foreign.Storable
import Data.Functor
import Data.Maybe (mapMaybe)

import Text.XkbCommon.InternalTypes

#include <xkbcommon/xkbcommon.h>


-- | Create a new keyboard state object for a keymap. (@xkb_state_new@)
newKeyboardState :: Keymap -> IO KeyboardState
newKeyboardState km = withKeymap km $
      \ ptr -> do
         k <- c_new_keyboard_state ptr
         l <- newForeignPtr c_unref_keyboard_state k
         return $ toKeyboardState l

-- | Update the keyboard state to reflect a given key being pressed or released. (@xkb_state_update_key@)
updateKeyboardStateKey :: KeyboardState -> CKeycode -> Direction -> IO StateComponent
updateKeyboardStateKey st key dir = withKeyboardState st $
      \ ptr -> c_update_key_state ptr key dir

-- | Get the single keysym obtained from pressing a particular key in a given keyboard state.
--   (@xkb_state_key_get_one_sym@)
getOneKeySym :: KeyboardState -> CKeycode -> IO (Maybe Keysym)
getOneKeySym st key = withKeyboardState st $
      \ ptr -> do
         ks <- c_get_one_key_sym ptr key
         return $ safeToKeysym ks

-- | Get the keysyms obtained from pressing a particular key in a given keyboard state.
--   This function is useful because some keycode sequences produce multiple keysyms.
--
--   (@xkb_state_key_get_syms@)
getStateSyms :: KeyboardState -> CKeycode -> IO [Keysym]
getStateSyms st key = withKeyboardState st $ \ ptr -> do
   init_ptr <- newArray [] :: IO (Ptr CKeysym)
   in_ptr <- new init_ptr
   num_out <- c_state_get_syms ptr key in_ptr
   deref_ptr <- peek in_ptr
   out_list <- peekArray (fromIntegral num_out) deref_ptr
   --free deref_ptr >> free in_ptr >> free init_ptr
   free in_ptr >> free init_ptr
   return $ mapMaybe safeToKeysym out_list

-- Get the effective layout index for a key in a given keyboard state.
-- c_get_layout :: Ptr CKeyboardState -> CKeycode -> IO CLayoutIndex

-- Get the effective shift level for a key in a given keyboard state and layout.
-- c_key_get_level :: Ptr CKeyboardState -> CKeycode -> CLayoutIndex -> IO CLevelIndex

-- | Update a keyboard state from a set of explicit masks. (@xkb_state_update_mask@)
updateKeyboardStateMask :: KeyboardState -> (CModMask, CModMask, CModMask) -> (CLayoutIndex, CLayoutIndex, CLayoutIndex) -> IO StateComponent
updateKeyboardStateMask st (mask1, mask2, mask3) (idx1, idx2, idx3) = withKeyboardState st $ \ ptr ->
   c_update_state_mask ptr mask1 mask2 mask3 idx1 idx2 idx3

-- | The counterpart to xkb_state_update_mask for modifiers, to be used on the server side of
--   serialization. (@xkb_state_serialize_mods@)
stateSerializeMods :: KeyboardState -> StateComponent -> IO CModMask
stateSerializeMods st comp = withKeyboardState st $ \ ptr ->
   c_serialize_state_mods ptr comp

-- The counterpart to xkb_state_update_mask for layouts, to be used on the server side of serialization.
-- c_serialize_state :: Ptr CKeyboardState -> StateComponent -> IO CLayoutIndex

-- | Test whether a modifier is active in a given keyboard state by name.
--   (@xkb_state_mod_name_is_active@)
stateModNameIsActive :: KeyboardState -> String -> StateComponent -> IO Bool
stateModNameIsActive st name comp = withKeyboardState st $ \ ptr ->
   withCString name $ \ cstr -> do
      out <- c_state_mod_name_is_active ptr cstr comp
      return $ out > 0

-- | Test whether a modifier is active in a given keyboard state by index.
--   (@xkb_state_mod_index_is_active@)
stateModIndexIsActive :: KeyboardState -> CModIndex -> StateComponent -> IO Bool
stateModIndexIsActive st idx comp = withKeyboardState st $ \ ptr -> do
      out <- c_state_mod_index_is_active ptr idx comp
      return $ out > 0

-- Test whether a modifier is consumed by keyboard state translation for a key.
-- c_modifier_is_consumed :: Ptr CKeyboardState -> CKeycode -> CModIndex -> IO CInt

-- | Remove consumed modifiers from a modifier mask for a key.
--   (@xkb_state_mod_mask_remove_consumed@)
stateRemoveConsumed :: KeyboardState -> CKeycode -> CModMask -> IO CModMask
stateRemoveConsumed st kc mask = withKeyboardState st $ \ ptr ->
   c_remove_consumed_modifiers ptr kc mask

-- Test whether a layout is active in a given keyboard state by name.
-- c_layout_name_is_active :: Ptr CKeyboardState -> CString -> StateComponent -> IO CInt

-- Test whether a layout is active in a given keyboard state by index.
-- c_layout_index_is_active :: Ptr CKeyboardState -> CLayoutIndex -> StateComponent -> IO CInt

-- | Test whether a LED is active in a given keyboard state by name.
--   (@xkb_state_led_name_is_active@)
stateLedNameIsActive :: KeyboardState -> String -> IO Bool
stateLedNameIsActive st name = withKeyboardState st $ \ ptr ->
   withCString name $ \ cstr -> do
      out <- c_led_name_is_active ptr cstr
      return $ out > 0

-- Test whether a LED is active in a given keyboard state by index.
-- c_led_index_is_active :: Ptr CKeyboardState -> CLedIndex -> IO CInt



-- keymap state related

foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_new"
   c_new_keyboard_state :: Ptr CKeymap -> IO (Ptr CKeyboardState)

foreign import ccall unsafe "xkbcommon/xkbcommon.h &xkb_state_unref"
   c_unref_keyboard_state :: FinalizerPtr CKeyboardState

foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_update_key"
   c_update_key_state :: Ptr CKeyboardState -> CKeycode -> Direction -> IO StateComponent

foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_key_get_one_sym"
   c_get_one_key_sym :: Ptr CKeyboardState -> CKeycode -> IO CKeysym

-- int    xkb_state::xkb_state_key_get_syms (struct xkb_state *state, xkb_keycode_t key, const xkb_keysym_t **syms_out)
--     Get the keysyms obtained from pressing a particular key in a given keyboard state.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_key_get_syms"
   c_state_get_syms :: Ptr CKeyboardState -> CKeycode -> Ptr (Ptr CKeysym) -> IO CInt

-- xkb_layout_index_t    xkb_state::xkb_state_key_get_layout (struct xkb_state *state, xkb_keycode_t key)
--     Get the effective layout index for a key in a given keyboard state.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_key_get_layout"
   c_get_layout :: Ptr CKeyboardState -> CKeycode -> IO CLayoutIndex

-- xkb_level_index_t    xkb_state::xkb_state_key_get_level (struct xkb_state *state, xkb_keycode_t key, xkb_layout_index_t layout)
--     Get the effective shift level for a key in a given keyboard state and layout.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_key_get_level"
   c_key_get_level :: Ptr CKeyboardState -> CKeycode -> CLayoutIndex -> IO CLevelIndex

-- enum xkb_state_component    xkb_state::xkb_state_update_mask (struct xkb_state *state, xkb_mod_mask_t depressed_mods, xkb_mod_mask_t latched_mods, xkb_mod_mask_t locked_mods, xkb_layout_index_t depressed_layout, xkb_layout_index_t latched_layout, xkb_layout_index_t locked_layout)
--     Update a keyboard state from a set of explicit masks.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_update_mask"
   c_update_state_mask :: Ptr CKeyboardState -> CModMask -> CModMask -> CModMask -> CLayoutIndex -> CLayoutIndex -> CLayoutIndex -> IO StateComponent

-- xkb_mod_mask_t    xkb_state::xkb_state_serialize_mods (struct xkb_state *state, enum xkb_state_component components)
--     The counterpart to xkb_state_update_mask for modifiers, to be used on the server side of serialization.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_serialize_mods"
   c_serialize_state_mods :: Ptr CKeyboardState -> StateComponent -> IO CModMask

-- xkb_layout_index_t    xkb_state::xkb_state_serialize_layout (struct xkb_state *state, enum xkb_state_component components)
--     The counterpart to xkb_state_update_mask for layouts, to be used on the server side of serialization.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_serialize_layout"
   c_serialize_state :: Ptr CKeyboardState -> StateComponent -> IO CLayoutIndex

-- int    xkb_state::xkb_state_mod_name_is_active (struct xkb_state *state, const char *name, enum xkb_state_component type)
--     Test whether a modifier is active in a given keyboard state by name.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_mod_name_is_active"
   c_state_mod_name_is_active :: Ptr CKeyboardState -> CString -> StateComponent -> IO Int

-- cannot be ccalled due to va_list. libxkbcommon devs say they aren't that useful anyway.
-- int    xkb_state::xkb_state_mod_names_are_active (struct xkb_state *state, enum xkb_state_component type, enum xkb_state_match match,...)
--     Test whether a set of modifiers are active in a given keyboard state by name.
-- foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_mod_names_are_active"

-- int    xkb_state::xkb_state_mod_index_is_active (struct xkb_state *state, xkb_mod_index_t idx, enum xkb_state_component type)
--     Test whether a modifier is active in a given keyboard state by index.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_mod_index_is_active"
   c_state_mod_index_is_active :: Ptr CKeyboardState -> CModIndex -> StateComponent -> IO CInt

-- cannot be ccalled due to va_list
-- int    xkb_state::xkb_state_mod_indices_are_active (struct xkb_state *state, enum xkb_state_component type, enum xkb_state_match match,...)
--     Test whether a set of modifiers are active in a given keyboard state by index.
-- foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_mod_indices_are_active"

-- int    xkb_state::xkb_state_mod_index_is_consumed (struct xkb_state *state, xkb_keycode_t key, xkb_mod_index_t idx)
--     Test whether a modifier is consumed by keyboard state translation for a key.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_mod_index_is_consumed"
   c_modifier_is_consumed :: Ptr CKeyboardState -> CKeycode -> CModIndex -> IO CInt

-- xkb_mod_mask_t    xkb_state::xkb_state_mod_mask_remove_consumed (struct xkb_state *state, xkb_keycode_t key, xkb_mod_mask_t mask)
--     Remove consumed modifiers from a modifier mask for a key.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_mod_mask_remove_consumed"
   c_remove_consumed_modifiers :: Ptr CKeyboardState -> CKeycode -> CModMask -> IO CModMask

-- int    xkb_state::xkb_state_layout_name_is_active (struct xkb_state *state, const char *name, enum xkb_state_component type)
--     Test whether a layout is active in a given keyboard state by name.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_layout_name_is_active"
   c_layout_name_is_active :: Ptr CKeyboardState -> CString -> StateComponent -> IO CInt

-- int    xkb_state::xkb_state_layout_index_is_active (struct xkb_state *state, xkb_layout_index_t idx, enum xkb_state_component type)
--     Test whether a layout is active in a given keyboard state by index.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_layout_index_is_active"
   c_layout_index_is_active :: Ptr CKeyboardState -> CLayoutIndex -> StateComponent -> IO CInt

-- int    xkb_state::xkb_state_led_name_is_active (struct xkb_state *state, const char *name)
--     Test whether a LED is active in a given keyboard state by name.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_led_name_is_active"
   c_led_name_is_active :: Ptr CKeyboardState -> CString -> IO CInt

-- int    xkb_state::xkb_state_led_index_is_active (struct xkb_state *state, xkb_led_index_t idx)
--     Test whether a LED is active in a given keyboard state by index.
foreign import ccall unsafe "xkbcommon/xkbcommon.h xkb_state_led_index_is_active"
   c_led_index_is_active :: Ptr CKeyboardState -> CLedIndex -> IO CInt

