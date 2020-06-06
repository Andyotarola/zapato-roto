/* CREACIÓN DE LA BASE DE DATOS */

CREATE DATABASE zapato_roto;

/* CREACIÓN DE LA TABLA PRODUCTOS */ 
CREATE TABLE productos (
	id smallserial,
	nombre varchar(100) NOT NULL,
	presentacion text NOT NULL,
	valor real NOT NULL,
	CONSTRAINT pk_productos PRIMARY KEY(id),
	CONSTRAINT uk_nombre_productos UNIQUE (nombre),
	CONSTRAINT ch_valor_productos CHECK (valor > 0)
) 

/* CREACIÓN DE LA TABLA COMPRAS.ESTO ES ÚTIL AL MOMENTO DE LLENAR EL INVENTARIO*/
CREATE TABLE compras (
	id smallserial,
	producto smallint NOT NULL,
	cantidad smallint NOT NULL,
	CONSTRAINT pk_compras PRIMARY KEY(id),
	CONSTRAINT ch_cantidad_compras CHECK (cantidad > 0),
	CONSTRAINT fk_compras_productos FOREIGN  KEY  (producto)
	REFERENCES productos (id) ON DELETE RESTRICT ON UPDATE RESTRICT
) 

/* CREACIÓN DE LA TABLA INVENTARIOS*/
CREATE TABLE inventarios(
	id smallserial,
	producto smallint NOT NULL,
	cantidad smallint NOT NULL,
	CONSTRAINT pk_inventarios PRIMARY KEY(id),
	CONSTRAINT fk_inventarios_productos FOREIGN  KEY  (producto)
	REFERENCES productos (id) ON DELETE RESTRICT ON UPDATE RESTRICT
)

/* CREACION DE LA TABLA AUDITORIA.PARA CONTROLAR LOS PRODUCTOS*/
CREATE TABLE auditoria(
	id smallserial,
	inventario smallint NOT NULL,
	cantidad smallint NOT NULL,
   tipo_movimiento varchar(7) NOT NULL,
   fecha timestamp NOT NULL,
	CONSTRAINT pk_auditoria PRIMARY KEY(id),
	CONSTRAINT ch_cantidad_auditoria  CHECK (cantidad > 0),
	CONSTRAINT ch_tipo_movimiento_auditoria CHECK (tipo_movimiento IN ('ENTRADA', 'SALIDA')),
	CONSTRAINT fk_auditoria_inventarios FOREIGN  KEY  (inventario)
	REFERENCES inventarios (id) ON DELETE RESTRICT ON UPDATE RESTRICT
)

/* CREACIÓN DE LA TABLA ClIENTES*/
CREATE TABLE clientes(
	id  smallserial,
	nom_nombres varchar (100) NOT NULL,
	nom_apellidos varchar (100) NOT NULL,
	pais varchar(100) NOT NULL,
	CONSTRAINT pk_clientes PRIMARY KEY(id)
)

/* CREACION DE LA TABLA FACTURAS*/
CREATE TABLE facturas(
	codigo_factura smallserial,
	cliente smallint NOT NULL,
	descuento real NOT NULL,
	producto smallint NOT NULL,
	impuesto real NOT NULL,
	total real NOT NULL,
	cantidad smallint NOT NULL,
   fecha timestamp NOT NULL,
	CONSTRAINT pk_facturas PRIMARY KEY(codigo_factura),
	CONSTRAINT ch_cantidad_productos CHECK (cantidad > 0),
	CONSTRAINT fk_facturas_productos FOREIGN KEY (producto)
	REFERENCES productos (id) ON DELETE RESTRICT ON UPDATE RESTRICT,
	CONSTRAINT fk_facturas_clientes FOREIGN KEY (cliente)
	REFERENCES clientes (id) ON DELETE RESTRICT ON UPDATE RESTRICT 
)	

/* CREACION DE FUNCIONES Y TRIGGERS */

-- Función para crear o actualizar un inventario de un determinado producto.
CREATE OR REPLACE FUNCTION updateOrCreateInventory()
RETURNS TRIGGER AS
$BODY$
DECLARE
	inventario_id inventarios.id%TYPE;
BEGIN				
   PERFORM producto FROM inventarios WHERE producto = NEW.producto;
	   IF FOUND THEN
		   UPDATE inventarios SET cantidad = cantidad + NEW.cantidad
	   	WHERE producto = NEW.producto RETURNING id INTO inventario_id;
      ELSE 
	   	INSERT INTO inventarios (producto, cantidad) 
		   VALUES (NEW.producto, NEW.cantidad) RETURNING id INTO inventario_id;
      END IF;	
      
      INSERT INTO auditoria (cantidad, fecha , inventario, tipo_movimiento) 
      VALUES (NEW.cantidad, now(), inventario_id, 'ENTRADA');

	   RETURN NEW;
END
$BODY$
LANGUAGE plpgsql;

-- Función para validar si la facturación es correcta
CREATE OR REPLACE FUNCTION valida_facturacion()
RETURNS TRIGGER AS
$BODY$
DECLARE
   product productos%ROWTYPE;
   inventario	inventarios%ROWTYPE;
													 
BEGIN
	SELECT * INTO inventario FROM inventarios WHERE producto = NEW.producto;
	IF FOUND THEN
		IF inventario.cantidad >= NEW.cantidad THEN
			UPDATE inventarios SET cantidad = cantidad - NEW.cantidad 
			WHERE producto = NEW.producto;

			INSERT INTO auditoria (cantidad, fecha , inventario, tipo_movimiento) 
		    VALUES (NEW.cantidad, now(), inventario.id, 'SALIDA');
		ELSE
			RAISE EXCEPTION 'No hay suficente cantidad para la venta.Solo hay :%',inventario.cantidad;
		END IF;
		SELECT * INTO product FROM productos WHERE id = NEW.producto;
		NEW.total = product.valor*(1 + NEW.impuesto)*(1 - NEW.descuento)*NEW.cantidad;
		NEW.fecha = now();
		RETURN NEW;
   ELSE
	 RAISE EXCEPTION 'No existe el producto';
   END IF;
END
$BODY$
LANGUAGE plpgsql										
													 
-- Trigger para crear o actualizar un inventario de un determinado producto.
CREATE TRIGGER updateOrCreateInventory
AFTER INSERT
ON compras
FOR EACH ROW EXECUTE PROCEDURE updateOrCreateInventory();

-- Trigger para validar si la facturación es correcta
CREATE TRIGGER valida_facturacion
BEFORE INSERT
ON facturas
FOR EACH ROW EXECUTE PROCEDURE valida_facturacion()

/* Poblando  productos*/					

INSERT INTO productos (nombre, presentacion, valor) 
VALUES ('ZAPATO MARQUIS', '¡Comodidad y estilo para tus pies! Combina tus mejores prendas', 160.95);

INSERT INTO productos (nombre, presentacion, valor) 
VALUES ('SPRINGFIELD', '¡Comodidad y estilo para tus pies! Combina tus mejores prendas de verano', 100.00);

INSERT INTO productos (nombre, presentacion, valor) 
VALUES ('DAUSS ZAPATOS', 'Lo mejor en calzado masculino ', 199.99);


/* Poblando clientes */
INSERT INTO clientes (nom_nombres, nom_apellidos, pais)									   
VALUES ('Andy', 'Otárola', 'Perú')

INSERT INTO clientes (nom_nombres, nom_apellidos, pais)									   
VALUES ('Alexis', 'Lozada', 'Colombia')

INSERT INTO clientes (nom_nombres, nom_apellidos, pais)									   
VALUES ('Alvaro', 'Felipe', 'Perú')

INSERT INTO clientes (nom_nombres, nom_apellidos, pais)									   
VALUES ('Beto ', 'Quiroga', 'Bolivia')


/* Poblando inventario*/

-- EL producto es "ZAPATO MARQUIS "	   
INSERT INTO compras  (producto, cantidad) 
VALUES (1, 20);

-- EL producto es "SPRINGFIELD "	   
INSERT INTO compras  (producto, cantidad) 
VALUES (2, 14);

-- EL producto es "DAUSS ZAPATOS "	   
INSERT INTO compras  (producto, cantidad) 
VALUES (3, 30);


/*Poblando facturas*/

-- EL producto es "ZAPATO MARQUIS" y el cliente es "Andy Otárola"	 
INSERT INTO facturas (producto, cliente, descuento, impuesto, cantidad)
VALUES (1, 1, 0.8, 0.18, 4)

-- EL producto es "SPRINGFIELD" y el cliente es "Alexis Lozada"	 
INSERT INTO facturas (producto, cliente, descuento, impuesto, cantidad)
VALUES (2, 2, 0.6, 0.18, 10)

-- EL producto es "DAUSS ZAPATOS" y el cliente es "Alvaro Felipe"	 
INSERT INTO facturas (producto, cliente, descuento, impuesto, cantidad)
VALUES (3, 3, 0.4, 0.18, 8)

-- EL producto es "DAUSS ZAPATOS" y el cliente es "Beto Quiroga"	 
INSERT INTO facturas (producto, cliente, descuento, impuesto, cantidad)
VALUES (3, 4, 0.3, 0.18, 6)


-- Consultas para los requerimientos:
												   
-- 1)Consulta la facturación de un cliente en específico.
SELECT * from facturas WHERE cliente = 1

-- 2)Consulta la facturación de un producto en específico.
SELECT * from facturas WHERE producto = 1 AND cliente = 1

-- 3)Consulta la facturación de un rango de fechas.
SELECT * FROM facturas WHERE fecha BETWEEN '2020-06-06 01:15:50 ' AND '2020-06-06 01:22:45'

-- 4)De la facturación, consulta los clientes únicos (es decir, 
--   se requiere el listado de los clientes que han comprado por lo menos una vez, 
--   pero en el listado no se deben repetir los clientes)
SELECT cliente FROM facturas GROUP BY (cliente) HAVING COUNT(*) > 0