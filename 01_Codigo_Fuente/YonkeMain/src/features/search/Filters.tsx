import { Check } from 'lucide-react';
import { classNames } from '@/lib/utils';

export const CATEGORIAS = ['Motor', 'Transmisión', 'Suspensión', 'Eléctrico', 'Interiores', 'Carrocería'];

export interface FiltrosValor {
  categorias: string[];
  precioMin?: number;
  precioMax?: number;
}

interface FiltersProps {
  value: FiltrosValor;
  onChange: (value: FiltrosValor) => void;
}

const parsePrecio = (v: string) => (v === '' ? undefined : Number(v));

const inputClass =
  'w-full bg-field text-ink placeholder-ink-secondary px-4 py-3 transition-colors duration-150 focus:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-1 focus-visible:ring-offset-surface [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none';

export default function Filters({ value, onChange }: FiltersProps) {
  const toggleCategoria = (cat: string) => {
    const categorias = value.categorias.includes(cat)
      ? value.categorias.filter((c) => c !== cat)
      : [...value.categorias, cat];
    onChange({ ...value, categorias });
  };

  return (
    <div className="bg-surface p-6 space-y-10">
      <section>
        <h3 className="text-xl font-extrabold text-ink tracking-display mb-6">Categorías</h3>
        <ul className="space-y-1">
          {CATEGORIAS.map((cat) => {
            const activa = value.categorias.includes(cat);
            return (
              <li key={cat}>
                <button
                  type="button"
                  aria-pressed={activa}
                  onClick={() => toggleCategoria(cat)}
                  className={classNames(
                    'group w-full flex items-center gap-3 py-2 text-left transition-colors duration-150 outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-1 focus-visible:ring-offset-surface',
                    activa ? 'text-ink' : 'text-ink-secondary hover:text-accent'
                  )}
                >
                  <span
                    className={classNames(
                      'flex h-4 w-4 flex-shrink-0 items-center justify-center transition-colors duration-150',
                      activa ? 'bg-accent text-white' : 'bg-field group-hover:bg-border-subtle'
                    )}
                  >
                    {activa && <Check className="h-3 w-3" strokeWidth={3} />}
                  </span>
                  <span className="text-sm font-medium">{cat}</span>
                </button>
              </li>
            );
          })}
        </ul>
      </section>

      <section>
        <h3 className="text-xl font-extrabold text-ink tracking-display mb-6">Rango de precio</h3>
        <div className="flex items-center gap-3">
          <input
            type="number"
            placeholder="Mín"
            min={0}
            value={value.precioMin ?? ''}
            onChange={(e) => onChange({ ...value, precioMin: parsePrecio(e.target.value) })}
            className={inputClass}
          />
          <span className="text-ink-secondary">–</span>
          <input
            type="number"
            placeholder="Máx"
            min={0}
            value={value.precioMax ?? ''}
            onChange={(e) => onChange({ ...value, precioMax: parsePrecio(e.target.value) })}
            className={inputClass}
          />
        </div>
      </section>
    </div>
  );
}
