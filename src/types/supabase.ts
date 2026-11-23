export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      invoice_items: {
        Row: {
          cantidad: number
          descripcion: string
          factura_id: string
          id: number
          importe: number | null
          precio_unitario: number
          unidad: string
        }
        Insert: {
          cantidad: number
          descripcion: string
          factura_id: string
          id?: never
          importe?: number | null
          precio_unitario: number
          unidad?: string
        }
        Update: {
          cantidad?: number
          descripcion?: string
          factura_id?: string
          id?: never
          importe?: number | null
          precio_unitario?: number
          unidad?: string
        }
        Relationships: [
          {
            foreignKeyName: "invoice_items_factura_id_fkey"
            columns: ["factura_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
        ]
      }
      invoices: {
        Row: {
          created_at: string
          excede_referencia: boolean
          id: string
          justificacion_mano_obra: string | null
          mano_obra: number
          notas: string | null
          solicitud_id: string
          tecnico_id: string
          total: number | null
          total_materiales: number
        }
        Insert: {
          created_at?: string
          excede_referencia?: boolean
          id?: string
          justificacion_mano_obra?: string | null
          mano_obra: number
          notas?: string | null
          solicitud_id: string
          tecnico_id: string
          total?: number | null
          total_materiales?: number
        }
        Update: {
          created_at?: string
          excede_referencia?: boolean
          id?: string
          justificacion_mano_obra?: string | null
          mano_obra?: number
          notas?: string | null
          solicitud_id?: string
          tecnico_id?: string
          total?: number | null
          total_materiales?: number
        }
        Relationships: [
          {
            foreignKeyName: "invoices_solicitud_id_fkey"
            columns: ["solicitud_id"]
            isOneToOne: true
            referencedRelation: "service_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_solicitud_id_fkey"
            columns: ["solicitud_id"]
            isOneToOne: true
            referencedRelation: "v_solicitudes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_tecnico_id_fkey"
            columns: ["tecnico_id"]
            isOneToOne: false
            referencedRelation: "technician_profiles"
            referencedColumns: ["profile_id"]
          },
        ]
      }
      notifications: {
        Row: {
          created_at: string
          id: number
          leida: boolean
          mensaje: string
          solicitud_id: string | null
          usuario_id: string
        }
        Insert: {
          created_at?: string
          id?: never
          leida?: boolean
          mensaje: string
          solicitud_id?: string | null
          usuario_id: string
        }
        Update: {
          created_at?: string
          id?: never
          leida?: boolean
          mensaje?: string
          solicitud_id?: string | null
          usuario_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_solicitud_id_fkey"
            columns: ["solicitud_id"]
            isOneToOne: false
            referencedRelation: "service_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_solicitud_id_fkey"
            columns: ["solicitud_id"]
            isOneToOne: false
            referencedRelation: "v_solicitudes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_usuario_id_fkey"
            columns: ["usuario_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_usuario_id_fkey"
            columns: ["usuario_id"]
            isOneToOne: false
            referencedRelation: "tecnicos_publicos"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          activo: boolean
          apellidos: string
          created_at: string
          direccion: string | null
          id: string
          nombre: string
          rol: Database["public"]["Enums"]["user_role"]
          telefono: string | null
          updated_at: string
          zona_id: number | null
        }
        Insert: {
          activo?: boolean
          apellidos?: string
          created_at?: string
          direccion?: string | null
          id: string
          nombre?: string
          rol?: Database["public"]["Enums"]["user_role"]
          telefono?: string | null
          updated_at?: string
          zona_id?: number | null
        }
        Update: {
          activo?: boolean
          apellidos?: string
          created_at?: string
          direccion?: string | null
          id?: string
          nombre?: string
          rol?: Database["public"]["Enums"]["user_role"]
          telefono?: string | null
          updated_at?: string
          zona_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "profiles_zona_id_fkey"
            columns: ["zona_id"]
            isOneToOne: false
            referencedRelation: "zones"
            referencedColumns: ["id"]
          },
        ]
      }
      request_status_history: {
        Row: {
          cambiado_por: string | null
          created_at: string
          estado: Database["public"]["Enums"]["request_status"]
          id: number
          solicitud_id: string
        }
        Insert: {
          cambiado_por?: string | null
          created_at?: string
          estado: Database["public"]["Enums"]["request_status"]
          id?: never
          solicitud_id: string
        }
        Update: {
          cambiado_por?: string | null
          created_at?: string
          estado?: Database["public"]["Enums"]["request_status"]
          id?: never
          solicitud_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "request_status_history_cambiado_por_fkey"
            columns: ["cambiado_por"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "request_status_history_cambiado_por_fkey"
            columns: ["cambiado_por"]
            isOneToOne: false
            referencedRelation: "tecnicos_publicos"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "request_status_history_solicitud_id_fkey"
            columns: ["solicitud_id"]
            isOneToOne: false
            referencedRelation: "service_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "request_status_history_solicitud_id_fkey"
            columns: ["solicitud_id"]
            isOneToOne: false
            referencedRelation: "v_solicitudes"
            referencedColumns: ["id"]
          },
        ]
      }
      reviews: {
        Row: {
          calificacion: number
          cliente_id: string
          comentario: string | null
          created_at: string
          id: string
          solicitud_id: string
          tecnico_id: string
        }
        Insert: {
          calificacion: number
          cliente_id: string
          comentario?: string | null
          created_at?: string
          id?: string
          solicitud_id: string
          tecnico_id: string
        }
        Update: {
          calificacion?: number
          cliente_id?: string
          comentario?: string | null
          created_at?: string
          id?: string
          solicitud_id?: string
          tecnico_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reviews_cliente_id_fkey"
            columns: ["cliente_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_cliente_id_fkey"
            columns: ["cliente_id"]
            isOneToOne: false
            referencedRelation: "tecnicos_publicos"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_solicitud_id_fkey"
            columns: ["solicitud_id"]
            isOneToOne: true
            referencedRelation: "service_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_solicitud_id_fkey"
            columns: ["solicitud_id"]
            isOneToOne: true
            referencedRelation: "v_solicitudes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_tecnico_id_fkey"
            columns: ["tecnico_id"]
            isOneToOne: false
            referencedRelation: "technician_profiles"
            referencedColumns: ["profile_id"]
          },
        ]
      }
      service_categories: {
        Row: {
          activa: boolean
          descripcion: string | null
          id: number
          mano_obra_max: number | null
          nombre: string
        }
        Insert: {
          activa?: boolean
          descripcion?: string | null
          id?: never
          mano_obra_max?: number | null
          nombre: string
        }
        Update: {
          activa?: boolean
          descripcion?: string | null
          id?: never
          mano_obra_max?: number | null
          nombre?: string
        }
        Relationships: []
      }
      service_requests: {
        Row: {
          categoria_id: number
          cliente_id: string
          created_at: string
          descripcion: string
          direccion_servicio: string
          estado: Database["public"]["Enums"]["request_status"]
          fecha_programada: string
          id: string
          tecnico_id: string
          updated_at: string
          zona_id: number
        }
        Insert: {
          categoria_id: number
          cliente_id: string
          created_at?: string
          descripcion: string
          direccion_servicio: string
          estado?: Database["public"]["Enums"]["request_status"]
          fecha_programada: string
          id?: string
          tecnico_id: string
          updated_at?: string
          zona_id: number
        }
        Update: {
          categoria_id?: number
          cliente_id?: string
          created_at?: string
          descripcion?: string
          direccion_servicio?: string
          estado?: Database["public"]["Enums"]["request_status"]
          fecha_programada?: string
          id?: string
          tecnico_id?: string
          updated_at?: string
          zona_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "service_requests_categoria_id_fkey"
            columns: ["categoria_id"]
            isOneToOne: false
            referencedRelation: "service_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_cliente_id_fkey"
            columns: ["cliente_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_cliente_id_fkey"
            columns: ["cliente_id"]
            isOneToOne: false
            referencedRelation: "tecnicos_publicos"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_tecnico_id_fkey"
            columns: ["tecnico_id"]
            isOneToOne: false
            referencedRelation: "technician_profiles"
            referencedColumns: ["profile_id"]
          },
          {
            foreignKeyName: "service_requests_zona_id_fkey"
            columns: ["zona_id"]
            isOneToOne: false
            referencedRelation: "zones"
            referencedColumns: ["id"]
          },
        ]
      }
      technician_categories: {
        Row: {
          categoria_id: number
          tecnico_id: string
        }
        Insert: {
          categoria_id: number
          tecnico_id: string
        }
        Update: {
          categoria_id?: number
          tecnico_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "technician_categories_categoria_id_fkey"
            columns: ["categoria_id"]
            isOneToOne: false
            referencedRelation: "service_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "technician_categories_tecnico_id_fkey"
            columns: ["tecnico_id"]
            isOneToOne: false
            referencedRelation: "technician_profiles"
            referencedColumns: ["profile_id"]
          },
        ]
      }
      technician_profiles: {
        Row: {
          descripcion: string | null
          experiencia_anios: number
          profile_id: string
          promedio_calificacion: number
          rol: Database["public"]["Enums"]["user_role"]
          total_calificaciones: number
          verificacion: Database["public"]["Enums"]["verification_status"]
        }
        Insert: {
          descripcion?: string | null
          experiencia_anios?: number
          profile_id: string
          promedio_calificacion?: number
          rol?: Database["public"]["Enums"]["user_role"]
          total_calificaciones?: number
          verificacion?: Database["public"]["Enums"]["verification_status"]
        }
        Update: {
          descripcion?: string | null
          experiencia_anios?: number
          profile_id?: string
          promedio_calificacion?: number
          rol?: Database["public"]["Enums"]["user_role"]
          total_calificaciones?: number
          verificacion?: Database["public"]["Enums"]["verification_status"]
        }
        Relationships: [
          {
            foreignKeyName: "technician_profiles_profile_id_rol_fkey"
            columns: ["profile_id", "rol"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id", "rol"]
          },
        ]
      }
      technician_zones: {
        Row: {
          tecnico_id: string
          zona_id: number
        }
        Insert: {
          tecnico_id: string
          zona_id: number
        }
        Update: {
          tecnico_id?: string
          zona_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "technician_zones_tecnico_id_fkey"
            columns: ["tecnico_id"]
            isOneToOne: false
            referencedRelation: "technician_profiles"
            referencedColumns: ["profile_id"]
          },
          {
            foreignKeyName: "technician_zones_zona_id_fkey"
            columns: ["zona_id"]
            isOneToOne: false
            referencedRelation: "zones"
            referencedColumns: ["id"]
          },
        ]
      }
      zones: {
        Row: {
          activa: boolean
          id: number
          nombre: string
          zona_padre_id: number | null
        }
        Insert: {
          activa?: boolean
          id?: never
          nombre: string
          zona_padre_id?: number | null
        }
        Update: {
          activa?: boolean
          id?: never
          nombre?: string
          zona_padre_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "zones_zona_padre_id_fkey"
            columns: ["zona_padre_id"]
            isOneToOne: false
            referencedRelation: "zones"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      tecnicos_publicos: {
        Row: {
          apellidos: string | null
          categoria_ids: number[] | null
          descripcion: string | null
          experiencia_anios: number | null
          id: string | null
          nombre: string | null
          promedio_calificacion: number | null
          total_calificaciones: number | null
          zona_ids: number[] | null
        }
        Relationships: []
      }
      v_solicitudes: {
        Row: {
          calificacion: number | null
          categoria: string | null
          categoria_id: number | null
          cliente_id: string | null
          cliente_nombre: string | null
          comentario: string | null
          created_at: string | null
          descripcion: string | null
          direccion_servicio: string | null
          estado: Database["public"]["Enums"]["request_status"] | null
          fecha_programada: string | null
          id: string | null
          tecnico_id: string | null
          tecnico_nombre: string | null
          updated_at: string | null
          zona: string | null
          zona_id: number | null
        }
        Relationships: [
          {
            foreignKeyName: "service_requests_categoria_id_fkey"
            columns: ["categoria_id"]
            isOneToOne: false
            referencedRelation: "service_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_cliente_id_fkey"
            columns: ["cliente_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_cliente_id_fkey"
            columns: ["cliente_id"]
            isOneToOne: false
            referencedRelation: "tecnicos_publicos"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_requests_tecnico_id_fkey"
            columns: ["tecnico_id"]
            isOneToOne: false
            referencedRelation: "technician_profiles"
            referencedColumns: ["profile_id"]
          },
          {
            foreignKeyName: "service_requests_zona_id_fkey"
            columns: ["zona_id"]
            isOneToOne: false
            referencedRelation: "zones"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      admin_facturas_revision: {
        Args: { p_solo_excedidas?: boolean }
        Returns: {
          categoria: string
          created_at: string
          excede_referencia: boolean
          factura_id: string
          justificacion_mano_obra: string
          mano_obra: number
          mano_obra_max: number
          solicitud_id: string
          tecnico: string
          total: number
          total_materiales: number
        }[]
      }
      admin_ranking_tecnicos: {
        Args: { p_limit?: number }
        Returns: {
          nombre: string
          promedio: number
          servicios_finalizados: number
          tecnico_id: string
          total_calificaciones: number
        }[]
      }
      admin_reporte_servicios: {
        Args: { p_desde?: string; p_hasta?: string }
        Returns: {
          categoria: string
          estado: Database["public"]["Enums"]["request_status"]
          total: number
        }[]
      }
      admin_reporte_zonas: {
        Args: { p_desde?: string; p_hasta?: string }
        Returns: {
          estado: Database["public"]["Enums"]["request_status"]
          total: number
          zona: string
          zona_padre: string
        }[]
      }
      admin_resumen: { Args: never; Returns: Json }
      admin_set_usuario_activo: {
        Args: { p_activo: boolean; p_usuario: string }
        Returns: undefined
      }
      admin_verificar_tecnico: {
        Args: {
          p_estado: Database["public"]["Enums"]["verification_status"]
          p_tecnico: string
        }
        Returns: undefined
      }
      buscar_tecnicos: {
        Args: { p_categoria: number; p_zona: number }
        Returns: {
          apellidos: string
          descripcion: string
          experiencia_anios: number
          id: string
          nombre: string
          promedio_calificacion: number
          total_calificaciones: number
        }[]
      }
      cerrar_solicitud: {
        Args: {
          p_justificacion?: string
          p_mano_obra: number
          p_materiales?: Json
          p_notas?: string
          p_solicitud: string
        }
        Returns: string
      }
      is_admin: { Args: never; Returns: boolean }
      my_role: {
        Args: never
        Returns: Database["public"]["Enums"]["user_role"]
      }
      zone_covers: {
        Args: { p_tecnico: string; p_zona: number }
        Returns: boolean
      }
    }
    Enums: {
      request_status:
        | "pendiente"
        | "aceptado"
        | "en_proceso"
        | "finalizado"
        | "rechazado"
        | "cancelado"
      user_role: "cliente" | "tecnico" | "admin"
      verification_status: "pendiente" | "verificado" | "rechazado"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      request_status: [
        "pendiente",
        "aceptado",
        "en_proceso",
        "finalizado",
        "rechazado",
        "cancelado",
      ],
      user_role: ["cliente", "tecnico", "admin"],
      verification_status: ["pendiente", "verificado", "rechazado"],
    },
  },
} as const
