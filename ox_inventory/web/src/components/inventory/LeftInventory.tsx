import InventoryGrid from './InventoryGrid';
import { useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';

// ROX: slots 1-7 live in the loadout column (primary, secondary, quick use, gear)
export const LOADOUT_SLOTS = 7;
const pockets = (slot: number) => slot > LOADOUT_SLOTS;

const LeftInventory: React.FC = () => {
  const leftInventory = useAppSelector(selectLeftInventory);

  return <InventoryGrid inventory={leftInventory} filter={pockets} title="Inventory" className="rox-left" />;
};

export default LeftInventory;
