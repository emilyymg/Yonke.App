export interface Product {
  id: string | number;
  nombre: string;
  descripcion: string;
  precio: number;
  categoria: string;
  imagen?: string;
  galeria?: { grande: string; miniatura: string }[];
  condicion?: string;
  yonque?: {
    nombre: string;
    telefono?: string | null;
    correo?: string | null;
    ubicacion?: {
      direccion?: string | null;
      ciudad?: string | null;
      estado?: string | null;
      codigoPostal?: string | null;
    };
  };
  stock?: number;
  vehiculo_modelo?: string;
  año?: number;
}
