import InventoryGrid from './InventoryGrid';
import { useAppSelector } from '../../store';
import { selectRightInventory } from '../../store/inventory';

const RightInventory: React.FC = () => {
  const rightInventory = useAppSelector(selectRightInventory);
  const isDrop = rightInventory.type === 'drop' || rightInventory.type === 'newdrop';

  return <InventoryGrid inventory={rightInventory} title={isDrop ? 'Drop Inventory' : rightInventory.label} className="rox-right" />;
};

export default RightInventory;
