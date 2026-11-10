import { Button, Form, Input } from 'antd';
import { LockOutlined, LoginOutlined, MailOutlined } from '@ant-design/icons';
import { Link, useNavigate } from 'react-router-dom';
import TarjetaAuth from '../../components/ui/AuthCard';
import '../../styles/pages/Login.css';


interface ValoresLogin {
  email: string;
  password: string;
}

export default function Login() {
  const navigate = useNavigate();

  const enviar = (valores: ValoresLogin) => {
    console.log(valores); // solo para ver qué captura el formulario
    navigate('/seleccionRol'); // temporal, hasta tener el back
  };

  return (
    <TarjetaAuth
  icono={<LoginOutlined />}
  titulo="Bienvenido"
  subtitulo="Inicia sesión en tu cuenta"
>
  <Form<ValoresLogin>
    className="auth-form"
    layout="vertical"
    requiredMark={false}
    onFinish={enviar}
  >
    <Form.Item
      label="Correo"
      name="email"
      rules={[
        { required: true, message: 'Ingresa tu correo' },
        { type: 'email', message: 'Correo no válido' },
      ]}
    >
      <Input size="large" prefix={<MailOutlined />} placeholder="tu@ejemplo.com" />
    </Form.Item>

    <Form.Item
      name="password"
      rules={[{ required: true, message: 'Ingresa tu contraseña' }]}
      label={
        <div className="login-password-label">
          <span>Contraseña</span>
          <Link to="/recuperar">¿Olvidaste tu contraseña?</Link>
        </div>
      }
    >
      <Input.Password size="large" prefix={<LockOutlined />} placeholder="••••••••" />
    </Form.Item>

    <Button type="primary" htmlType="submit" size="large" block>
      Iniciar sesión
    </Button>
  </Form>
</TarjetaAuth>
  );
}