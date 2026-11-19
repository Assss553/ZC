// ROX Store | rarity colours for the ROX inventory theme
import type { Slot } from '../typings';

export type Rarity = 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary';

// item name -> rarity (anything not listed is "common"). metadata.rarity always wins.
export const ITEM_RARITY: Record<string, Rarity> = {
  armour: 'rare', phone: 'uncommon', radio: 'uncommon', card_id: 'rare', card_bank: 'rare', usb_black: 'rare',
  WEAPON_HANDCUFFS: 'rare', medikit: 'uncommon', advancedkit: 'rare', lockpick: 'uncommon', parachute: 'uncommon',
  black_money: 'epic', cocaine: 'epic', meth: 'epic', WEAPON_ASSAULTRIFLE: 'epic', WEAPON_CARBINERIFLE: 'epic',
  WEAPON_SPECIALCARBINE: 'epic', WEAPON_HEAVYSNIPER: 'legendary', WEAPON_RPG: 'legendary',
};

export const RARITY_INFO: Record<Rarity, { color: string; label: string }> = {
  common: { color: '#8d9096', label: 'Common' },
  uncommon: { color: '#47d17e', label: 'Uncommon' },
  rare: { color: '#4d8fe0', label: 'Rare' },
  epic: { color: '#a46be0', label: 'Epic' },
  legendary: { color: '#e8a93b', label: 'Legendary' },
};

export const getRarity = (item: Slot): Rarity => {
  const r = item?.metadata?.rarity as Rarity | undefined;
  if (r && RARITY_INFO[r]) return r;
  return (item?.name && ITEM_RARITY[item.name]) || 'common';
};

export const formatWeight = (w: number) =>
  w >= 1000 ? `${(w / 1000).toLocaleString('en-us', { maximumFractionDigits: 2 })} kg` : `${w.toLocaleString('en-us')} g`;
