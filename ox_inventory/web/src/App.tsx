import InventoryComponent from './components/inventory';
import useNuiEvent from './hooks/useNuiEvent';
import { Items } from './store/items';
import { Locale } from './store/locale';
import { setImagePath } from './store/imagepath';
import { setupInventory } from './store/inventory';
import { Inventory } from './typings';
import { useAppDispatch } from './store';
import { debugData } from './utils/debugData';
import DragPreview from './components/utils/DragPreview';
import { fetchNui } from './utils/fetchNui';
import { useDragDropManager } from 'react-dnd';
import KeyPress from './components/utils/KeyPress';

debugData([
  {
    action: 'init',
    data: { locale: { ui_use: 'Use', ui_give: 'Give', ui_close: 'Close' }, imagepath: 'images', items: { 'armour': { name: 'armour', label: 'Body Armour', stack: true, usable: true, close: true, count: 0 },'parachute': { name: 'parachute', label: 'Parachute', stack: true, usable: true, close: true, count: 0 },'paperbag': { name: 'paperbag', label: 'Paper Bag', stack: true, usable: true, close: true, count: 0 },'WEAPON_FIREEXTINGUISHER': { name: 'WEAPON_FIREEXTINGUISHER', label: 'Fire Extinguisher', stack: true, usable: true, close: true, count: 0 },'radio': { name: 'radio', label: 'Radio', stack: true, usable: true, close: true, count: 0 },'WEAPON_CROWBAR': { name: 'WEAPON_CROWBAR', label: 'Crowbar', stack: true, usable: true, close: true, count: 0 },'WEAPON_NIGHTSTICK': { name: 'WEAPON_NIGHTSTICK', label: 'Nightstick', stack: true, usable: true, close: true, count: 0 },'WEAPON_STUNGUN': { name: 'WEAPON_STUNGUN', label: 'Taser', stack: true, usable: true, close: true, count: 0 },'medikit': { name: 'medikit', label: 'Medikit', stack: true, usable: true, close: true, count: 0 },'card_bank': { name: 'card_bank', label: 'Bank Card', stack: true, usable: true, close: true, count: 0 },'card_id': { name: 'card_id', label: 'ID Card', stack: true, usable: true, close: true, count: 0 },'usb_black': { name: 'usb_black', label: 'USB', stack: true, usable: true, close: true, count: 0 },'WEAPON_PISTOL': { name: 'WEAPON_PISTOL', label: 'Pistol', stack: true, usable: true, close: true, count: 0 },'WEAPON_HANDCUFFS': { name: 'WEAPON_HANDCUFFS', label: 'Handcuffs', stack: true, usable: true, close: true, count: 0 },'ammo-9': { name: 'ammo-9', label: '9mm Ammo', stack: true, usable: true, close: true, count: 0 } }, leftInventory: { id: 'rox', type: 'player', slots: 40, label: '', weight: 0, maxWeight: 100000, items: [] } },
  },
  {
    action: 'setupInventory',
    data: {
      leftInventory: {
        id: 'rox', type: 'player', slots: 40, label: 'Inventory', weight: 50790, maxWeight: 100000,
        items: [
          { slot: 1, name: 'paperbag', weight: 200, count: 1 },
          { slot: 2, name: 'WEAPON_PISTOL', weight: 1200, count: 1, metadata: { durability: 100, ammo: 12 } },
          { slot: 3, name: 'card_id', weight: 10, count: 1 },
          { slot: 4, name: 'WEAPON_HANDCUFFS', weight: 300, count: 1 },
          { slot: 5, name: 'ammo-9', weight: 8, count: 398 },
          { slot: 8, name: 'armour', weight: 3500, count: 1, metadata: { durability: 100 } },
          { slot: 9, name: 'armour', weight: 3500, count: 1, metadata: { durability: 100 } },
          { slot: 10, name: 'parachute', weight: 900, count: 1 },
          { slot: 11, name: 'paperbag', weight: 200, count: 1, metadata: { durability: 90 } },
          { slot: 12, name: 'armour', weight: 3500, count: 1, metadata: { durability: 100 } },
          { slot: 14, name: 'WEAPON_FIREEXTINGUISHER', weight: 6000, count: 1, metadata: { durability: 100 } },
          { slot: 15, name: 'armour', weight: 2000, count: 1, metadata: { rarity: 'common' } },
          { slot: 16, name: 'radio', weight: 400, count: 3, metadata: { rarity: 'common' } },
          { slot: 17, name: 'WEAPON_CROWBAR', weight: 1500, count: 1 },
          { slot: 18, name: 'WEAPON_FIREEXTINGUISHER', weight: 6000, count: 1 },
          { slot: 19, name: 'radio', weight: 400, count: 1, metadata: { durability: 100 } },
          { slot: 20, name: 'WEAPON_NIGHTSTICK', weight: 600, count: 1, metadata: { durability: 100 } },
          { slot: 21, name: 'WEAPON_STUNGUN', weight: 300, count: 1 },
          { slot: 22, name: 'medikit', weight: 20, count: 8, metadata: { rarity: 'common' } },
          { slot: 24, name: 'card_bank', weight: 30, count: 1, metadata: { label: 'Transparency (Red)', description: 'A clear plastic sheet for an overhead projector. Marks in the corners line it up.' } },
          { slot: 25, name: 'card_id', weight: 30, count: 1, metadata: { label: 'Transparency (Blue)', description: 'A clear plastic sheet for an overhead projector. Marks in the corners line it up.' } },
          { slot: 26, name: 'armour', weight: 3500, count: 1, metadata: { durability: 30 } },
          { slot: 27, name: 'armour', weight: 2000, count: 1, metadata: { rarity: 'common' } },
          { slot: 29, name: 'usb_black', weight: 30, count: 1, metadata: { label: 'Transparency (Amber)', description: 'A clear plastic sheet for an overhead projector. Marks in the corners line it up.' } },
        ],
      },
      rightInventory: { id: 'drop', type: 'drop', slots: 5, label: 'Drop', weight: 0, maxWeight: 100000, items: [] },
    },
  },
]);

const App: React.FC = () => {
  const dispatch = useAppDispatch();
  const manager = useDragDropManager();

  useNuiEvent<{
    locale: { [key: string]: string };
    items: typeof Items;
    leftInventory: Inventory;
    imagepath: string;
  }>('init', ({ locale, items, leftInventory, imagepath }) => {
    for (const name in locale) Locale[name] = locale[name];
    for (const name in items) Items[name] = items[name];

    setImagePath(imagepath);
    dispatch(setupInventory({ leftInventory }));
  });

  fetchNui('uiLoaded', {});

  useNuiEvent('closeInventory', () => {
    manager.dispatch({ type: 'dnd-core/END_DRAG' });
  });

  return (
    <div className="app-wrapper">
      <InventoryComponent />
      <DragPreview />
      <KeyPress />
    </div>
  );
};

addEventListener('dragstart', function (event) {
  event.preventDefault();
});

export default App;
