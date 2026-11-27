import Link from 'next/link';
import Hero from '@/features/home/Hero';
import ProductCard from '@/features/product/ProductCard';
import Reveal from '@/components/Reveal';
import { Product } from '@/types';
import { productosApi } from '@/services/api';

async function getFeaturedProducts(): Promise<Product[]> {
  try {
    const products = await productosApi.listar(4);
    return products.slice(0, 4); // Por si el backend no respeta el límite temporalmente
  } catch (error) {
    console.error('Error fetching featured products:', error);
    return [];
  }
}

export default async function Home() {
  const products = await getFeaturedProducts();

  return (
    <div>
      <Hero />
      <section className="py-24 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <Reveal>
          <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-6 mb-12">
            <h2 className="text-3xl sm:text-4xl font-bold text-ink tracking-display leading-display">
              Productos Destacados
            </h2>
            <Link
              href="/explorar"
              className="inline-block self-start sm:self-auto px-5 py-2.5 font-medium bg-accent text-white hover:bg-accent-hover transition-colors duration-150 focus:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 focus-visible:ring-offset-ground"
            >
              Explorar →
            </Link>
          </div>
        </Reveal>
        {products.length > 0 ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {products.map((product, i) => (
              <Reveal key={product.id} delay={i * 80}>
                <ProductCard product={product} />
              </Reveal>
            ))}
          </div>
        ) : (
          <p className="text-ink-secondary text-lg">
            No hay productos destacados disponibles por el momento.
          </p>
        )}
      </section>
    </div>
  );
}
