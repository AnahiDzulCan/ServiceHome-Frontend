import { Button, Form, Input, Modal, message } from 'antd';
import type { Category } from '../../types/catalog';
import { toDateInput } from '../../utils/format';
import '../../styles/components/request-modal.css';

interface RequestValues {
  direccion: string;
  fecha: string; // YYYY-MM-DD
  hora: string; // HH:mm
  notas?: string;
}

interface Props {
  category: Category | null;
  open: boolean;
  onClose: () => void;
}

export default function RequestModal({ category, open, onClose }: Props) {
  const [form] = Form.useForm<RequestValues>();

  const handleFinish = (values: RequestValues) => {
    // Solo visual: muestra qué se enviaría. Aquí irá la llamada al servicio.
    console.log({ categoria_id: category?.id, ...values });
    message.success('Pedido enviado (demo)');
    onClose();
  };

  return (
    <Modal
      open={open}
      onCancel={onClose}
      afterClose={() => form.resetFields()}
      footer={null}
      centered
      width={440}
      className="request-modal"
      title={
        <div>
          <h2 className="request-modal-title">Solicitar {category?.nombre.toLowerCase()}</h2>
          <p className="request-modal-subtitle">{category?.descripcion}</p>
        </div>
      }
    >
      <Form<RequestValues>
        form={form}
        className="auth-form request-form"
        layout="vertical"
        requiredMark={false}
        initialValues={{ fecha: toDateInput(1), hora: '10:00' }}
        onFinish={handleFinish}
      >
        <Form.Item
          label="Dirección"
          name="direccion"
          rules={[
            { required: true, whitespace: true, message: 'Ingresa la dirección del servicio' },
            { min: 5, message: 'Mínimo 5 caracteres' },
            { max: 250, message: 'Máximo 250 caracteres' },
          ]}
        >
          <Input size="large" placeholder="Calle, número y colonia" />
        </Form.Item>

        <div className="request-form-row">
          <Form.Item
            label="Fecha"
            name="fecha"
            rules={[{ required: true, message: 'Elige la fecha' }]}
          >
            <Input size="large" type="date" min={toDateInput(0)} />
          </Form.Item>

          <Form.Item
            label="Hora"
            name="hora"
            dependencies={['fecha']}
            rules={[
              { required: true, message: 'Elige la hora' },
              ({ getFieldValue }) => ({
                validator(_, value) {
                  const fecha = getFieldValue('fecha');
                  if (!fecha || !value) return Promise.resolve();
                  const chosen = new Date(`${fecha}T${value}`);
                  return chosen.getTime() > Date.now()
                    ? Promise.resolve()
                    : Promise.reject(new Error('Elige una fecha y hora futuras'));
                },
              }),
            ]}
          >
            <Input size="large" type="time" />
          </Form.Item>
        </div>

        <Form.Item label="Notas (opcional)" name="notas">
          <Input.TextArea rows={3} maxLength={2000} placeholder="Cuéntanos qué necesitas" />
        </Form.Item>

        <Button type="primary" htmlType="submit" size="large" block>
          Confirmar pedido
        </Button>
      </Form>
    </Modal>
  );
}