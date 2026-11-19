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
    data: { locale: { ui_use: 'Use', ui_give: 'Give', ui_close: 'Close' }, imagepath: 'images', items: { 'rox_vest': { name: 'rox_vest', label: 'Plate Carrier', stack: true, usable: true, close: true, count: 0 },'rox_box': { name: 'rox_box', label: 'Package', stack: true, usable: true, close: true, count: 0 },'rox_oxygen': { name: 'rox_oxygen', label: 'Oxygen Tank', stack: true, usable: true, close: true, count: 0 },'rox_radio': { name: 'rox_radio', label: 'Radio', stack: true, usable: true, close: true, count: 0 },'rox_baton': { name: 'rox_baton', label: 'Baton', stack: true, usable: true, close: true, count: 0 },'rox_taser': { name: 'rox_taser', label: 'Taser', stack: true, usable: true, close: true, count: 0 },'rox_pills': { name: 'rox_pills', label: 'Painkillers', stack: true, usable: true, close: true, count: 0 },'rox_transparency_red': { name: 'rox_transparency_red', label: 'Transparency (Red)', stack: true, usable: true, close: true, count: 0 },'rox_transparency_blue': { name: 'rox_transparency_blue', label: 'Transparency (Blue)', stack: true, usable: true, close: true, count: 0 },'rox_transparency_amber': { name: 'rox_transparency_amber', label: 'Transparency (Amber)', stack: true, usable: true, close: true, count: 0 },'rox_idcard': { name: 'rox_idcard', label: 'ID Card', stack: true, usable: true, close: true, count: 0 },'rox_cuffs': { name: 'rox_cuffs', label: 'Handcuffs', stack: true, usable: true, close: true, count: 0 },'rox_ammo': { name: 'rox_ammo', label: 'Pistol Ammo', stack: true, usable: true, close: true, count: 0 },'parachute': { name: 'parachute', label: 'Parachute', stack: true, usable: true, close: true, count: 0 },'WEAPON_CROWBAR': { name: 'WEAPON_CROWBAR', label: 'Crowbar', stack: true, usable: true, close: true, count: 0 },'WEAPON_PISTOL': { name: 'WEAPON_PISTOL', label: 'Pistol', stack: true, usable: true, close: true, count: 0 } }, leftInventory: { id: 'rox', type: 'player', slots: 40, label: '', weight: 0, maxWeight: 100000, items: [] } },
  },
  {
    action: 'setupInventory',
    data: {
      leftInventory: {
        id: 'rox', type: 'player', slots: 40, label: 'Inventory', weight: 50790, maxWeight: 100000,
        items: [
          { slot: 1, name: 'rox_box', weight: 200, count: 1 },
          { slot: 2, name: 'WEAPON_PISTOL', weight: 1200, count: 1, metadata: { durability: 100, ammo: 12 } },
          { slot: 3, name: 'rox_idcard', weight: 10, count: 1 },
          { slot: 4, name: 'rox_cuffs', weight: 300, count: 1 },
          { slot: 5, name: 'rox_ammo', weight: 8, count: 398 },
          { slot: 8, name: 'rox_vest', weight: 3500, count: 1, metadata: { durability: 100 } },
          { slot: 9, name: 'rox_vest', weight: 3500, count: 1, metadata: { durability: 100 } },
          { slot: 10, name: 'parachute', weight: 900, count: 1 },
          { slot: 11, name: 'rox_box', weight: 200, count: 1, metadata: { durability: 90 } },
          { slot: 12, name: 'rox_vest', weight: 3500, count: 1, metadata: { durability: 100 } },
          { slot: 14, name: 'rox_oxygen', weight: 6000, count: 1, metadata: { durability: 100 } },
          { slot: 15, name: 'rox_vest', weight: 2000, count: 1, metadata: { rarity: 'common' } },
          { slot: 16, name: 'rox_radio', weight: 400, count: 3, metadata: { rarity: 'common' } },
          { slot: 17, name: 'WEAPON_CROWBAR', weight: 1500, count: 1 },
          { slot: 18, name: 'rox_oxygen', weight: 6000, count: 1 },
          { slot: 19, name: 'rox_radio', weight: 400, count: 1, metadata: { durability: 100 } },
          { slot: 20, name: 'rox_baton', weight: 600, count: 1, metadata: { durability: 100 } },
          { slot: 21, name: 'rox_taser', weight: 300, count: 1 },
          { slot: 22, name: 'rox_pills', weight: 20, count: 8, metadata: { rarity: 'common' } },
          { slot: 24, name: 'rox_transparency_red', weight: 30, count: 1, metadata: { label: 'Transparency (Red)', description: 'A clear plastic sheet for an overhead projector. Marks in the corners line it up.' } },
          { slot: 25, name: 'rox_transparency_blue', weight: 30, count: 1, metadata: { label: 'Transparency (Blue)', description: 'A clear plastic sheet for an overhead projector. Marks in the corners line it up.' } },
          { slot: 26, name: 'rox_vest', weight: 3500, count: 1, metadata: { durability: 30 } },
          { slot: 27, name: 'rox_vest', weight: 2000, count: 1, metadata: { rarity: 'common' } },
          { slot: 29, name: 'rox_transparency_amber', weight: 30, count: 1, metadata: { label: 'Transparency (Amber)', description: 'A clear plastic sheet for an overhead projector. Marks in the corners line it up.' } },
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
