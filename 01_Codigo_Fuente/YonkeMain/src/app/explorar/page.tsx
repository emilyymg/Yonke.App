import Link from 'next/link';
import ProductCard from '@/features/product/ProductCard';
import { productosApi } from '@/services/api';
import { Product } from '@/types';

export const dynamic = 'force-dynamic';

const POR_PAGINA = 12;

export default async function ExplorarPage({
  searchParams,
}: {
  searchParams: Promise<{ pagina?: string }>;
}) {
  const params = await searchParams;
  const pagina = Math.max(1, parseInt(params.pagina || '1', 10) || 1);

  let productos: Product[] = [];
  let hayMas = false;
  let error = false;

  try {
    // Pido uno extra para saber si existe una página siguiente.
    const data = await productosApi.listar(POR_PAGINA + 1, (pagina - 1) * POR_PAGINA);
    hayMas = data.length > POR_PAGINA;
    productos = data.slice(0, POR_PAGINA);
  } catch (e) {
    console.error(e);
    error = true;
  }

  const enlaceClase = 'px-5 py-2.5 font-medium transition-colors duration-150 bg-surface text-ink hover:bg-field focus:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 focus-visible:ring-offset-ground';
  const deshabilitadoClase = 'px-5 py-2.5 font-medium bg-surface text-ink-secondary opacity-50 cursor-not-allowed';

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <div className="mb-12">
        <h1 className="text-3xl sm:text-4xl font-bold text-ink tracking-display leading-display mb-3">
          Todas las publicaciones
        </h1>
        <p className="text-ink-secondary">Página {pagina}</p>
      </div>

      {error ? (
        <p className="text-ink-secondary text-lg">No se pudieron cargar las publicaciones.</p>
      ) : productos.length === 0 ? (
        <div className="text-ink-secondary">
          <p className="text-lg">No hay publicaciones en esta página.</p>
          <Link href="/explorar" className="inline-block mt-4 text-accent hover:text-accent-hover font-medium">
            Volver a la primera página
          </Link>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {productos.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      )}

      <nav className="mt-12 flex items-center justify-center gap-4" aria-label="Paginación">
        {pagina > 1 ? (
          <Link href={`/explorar?pagina=${pagina - 1}`} className={enlaceClase}>
            ← Anterior
          </Link>
        ) : (
          <span className={deshabilitadoClase} aria-disabled="true">← Anterior</span>
        )}
        <span className="text-ink-secondary text-sm">Página {pagina}</span>
        {hayMas ? (
          <Link href={`/explorar?pagina=${pagina + 1}`} className={enlaceClase}>
            Siguiente →
          </Link>
        ) : (
          <span className={deshabilitadoClase} aria-disabled="true">Siguiente →</span>
        )}
      </nav>
    </div>
  );
}
