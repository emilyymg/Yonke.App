"use client";

import { ReactNode, useState } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { Product } from '@/types';
import { classNames, formatCurrency } from '@/lib/utils';

function Dato({ etiqueta, children, className }: { etiqueta: string; children: ReactNode; className?: string }) {
  return (
    <div className={className}>
      <dt className="text-sm text-ink-secondary mb-1">{etiqueta}</dt>
      <dd className="text-ink text-lg break-words">{children ?? '—'}</dd>
    </div>
  );
}

export default function ProductDetail({ product }: { product: Product }) {
  const fotos =
    product.galeria && product.galeria.length > 0
      ? product.galeria
      : product.imagen
        ? [{ grande: product.imagen, miniatura: product.imagen }]
        : [];
  const [indice, setIndice] = useState(0);
  const actual = fotos[indice];

  const anterior = () => setIndice((i) => (i - 1 + fotos.length) % fotos.length);
  const siguiente = () => setIndice((i) => (i + 1) % fotos.length);

  const flechaClase =
    'flex-shrink-0 p-2 bg-surface text-ink-secondary hover:text-ink hover:bg-field transition-colors duration-150 outline-none focus-visible:ring-2 focus-visible:ring-accent';

  const yonque = product.yonque;
  const ubicacion = yonque?.ubicacion;
  const direccion = [
    ubicacion?.direccion,
    ubicacion?.ciudad,
    ubicacion?.estado,
    ubicacion?.codigoPostal ? `C.P. ${ubicacion.codigoPostal}` : null,
  ].filter(Boolean).join(', ') || null;
  const condicion = product.condicion
    ? product.condicion.charAt(0).toUpperCase() + product.condicion.slice(1)
    : null;

  return (
    <>
      <div className="grid grid-cols-1 lg:grid-cols-5 gap-16">
        {/* Image — 60% width */}
        <div className="lg:col-span-3">
          <div className="aspect-square bg-field overflow-hidden">
            {actual ? (
              <img
                src={actual.grande}
                alt={product.nombre}
                className="object-contain w-full h-full"
              />
            ) : (
              <div className="flex items-center justify-center w-full h-full text-ink-secondary text-xl">
                Sin imagen
              </div>
            )}
          </div>

          {/* Carrusel pequeño de miniaturas */}
          {fotos.length > 1 && (
            <div className="mt-4 flex items-center gap-3">
              <button type="button" onClick={anterior} aria-label="Foto anterior" className={flechaClase}>
                <ChevronLeft className="h-5 w-5" />
              </button>
              <div className="flex flex-1 gap-2 overflow-x-auto py-1">
                {fotos.map((foto, i) => (
                  <button
                    key={`${foto.miniatura}-${i}`}
                    type="button"
                    onClick={() => setIndice(i)}
                    aria-label={`Ver foto ${i + 1}`}
                    aria-current={i === indice}
                    className={classNames(
                      'flex-shrink-0 w-20 h-16 bg-field overflow-hidden outline-none transition-opacity duration-150 focus-visible:ring-2 focus-visible:ring-accent',
                      i === indice ? 'ring-2 ring-accent' : 'opacity-60 hover:opacity-100'
                    )}
                  >
                    <img src={foto.miniatura} alt="" className="w-full h-full object-contain" />
                  </button>
                ))}
              </div>
              <button type="button" onClick={siguiente} aria-label="Foto siguiente" className={flechaClase}>
                <ChevronRight className="h-5 w-5" />
              </button>
            </div>
          )}
        </div>

        {/* Info — 40% width */}
        <div className="lg:col-span-2 flex flex-col">
          <p className="text-sm text-ink-secondary mb-3">{product.categoria}</p>

          <h1 className="text-4xl font-extrabold text-ink tracking-display leading-display mb-4">
            {product.nombre}
          </h1>

          <p className="text-ink-secondary text-lg leading-relaxed mb-8">
            {product.descripcion}
          </p>

          {/* Price — dominant */}
          <div className="mb-10">
            <span className="text-5xl font-extrabold text-accent tracking-display">
              {formatCurrency(product.precio)}
            </span>
            <span className="ml-3 text-ink-secondary">MXN</span>
          </div>

          {/* Trust */}
          <div className="mb-8 text-ink-secondary">
            <p>Garantía de funcionamiento de 30 días</p>
          </div>

          {/* Stock */}
          {product.stock !== undefined && (
            <div className="mt-auto pt-8">
              <p className="text-sm text-ink-secondary">
                Stock disponible: {product.stock} unidades
              </p>
            </div>
          )}
        </div>
      </div>

      {/* Información del yonque */}
      {yonque && (
        <section className="mt-16 bg-surface p-6 sm:p-8">
          <h2 className="text-2xl font-extrabold text-ink tracking-display mb-8">
            Información del yonque
          </h2>
          <dl className="grid grid-cols-1 sm:grid-cols-2 gap-x-10 gap-y-6">
            <Dato etiqueta="Yonque">{yonque.nombre}</Dato>
            <Dato etiqueta="Condición de la pieza">{condicion}</Dato>
            <Dato etiqueta="Teléfono">
              {yonque.telefono ? (
                <a href={`tel:${yonque.telefono}`} className="hover:text-accent transition-colors duration-150">
                  {yonque.telefono}
                </a>
              ) : null}
            </Dato>
            <Dato etiqueta="Correo">
              {yonque.correo ? (
                <a href={`mailto:${yonque.correo}`} className="hover:text-accent transition-colors duration-150">
                  {yonque.correo}
                </a>
              ) : null}
            </Dato>
            <Dato etiqueta="Ubicación" className="sm:col-span-2">
              {direccion}
            </Dato>
          </dl>
        </section>
      )}
    </>
  );
}
