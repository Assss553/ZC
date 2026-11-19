// ROX Store | loadout column: Primary / Secondary / Quick use / Gear (player slots 1-7)
import React from 'react';
import { useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import InventorySlot from './InventorySlot';
import { Slot } from '../../typings';

const InventoryLoadout: React.FC = () => {
  const inv = useAppSelector(selectLeftInventory);
  const isBusy = useAppSelector((state) => state.inventory.isBusy);
  const bySlot = (n: number): Slot => inv.items.find((i) => i.slot === n) || { slot: n };
  const slot = (n: number, variant: 'weapon' | 'quick' | 'gear') => (
    <InventorySlot key={`loadout-${n}`} item={bySlot(n)} variant={variant} inventoryType={inv.type} inventoryGroups={inv.groups} inventoryId={inv.id} />
  );

  if (!inv.items.length) return null;

  return (
    <div className="rox-loadout" style={{ pointerEvents: isBusy ? 'none' : 'auto' }}>
      <div className="rox-pair">
        <div>
          <p className="rox-h">Primary</p>
          <div className="rox-pair-slot">{slot(1, 'weapon')}<span className="rox-ok" /></div>
        </div>
        <div>
          <p className="rox-h">Secondary</p>
          <div className="rox-pair-slot">{slot(2, 'weapon')}<span className="rox-ok" /></div>
        </div>
      </div>
      <p className="rox-h">Quick use</p>
      <div className="rox-quick">{[3, 4, 5].map((n) => slot(n, 'quick'))}</div>
      <p className="rox-h">Gear</p>
      <div className="rox-gear">{[6, 7].map((n) => slot(n, 'gear'))}</div>
    </div>
  );
};

export default InventoryLoadout;
