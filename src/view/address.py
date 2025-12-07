from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict, field_validator
import re


class UserAddressBase(BaseModel):
    
    street: Optional[str] = Field(default=None, description="Logradouro (Rua, Av, etc)")
    number: Optional[str] = Field(default=None, description="Número (aceita letras, ex: 100A, S/N)")
    neighborhood: Optional[str] = Field(default=None, description="Bairro")
    
    ibge_city_code: Optional[str] = Field(
        default=None, 
        min_length=7, 
        max_length=7,
        description="Código IBGE da cidade (7 dígitos). Ex: 4205407"
    )
    
    zip_code: Optional[str] = Field(
        default=None, 
        description="CEP (apenas números ou formatado 00000-000)"
    )
    
    state: Optional[str] = Field(
        default=None, 
        min_length=2, 
        max_length=2,
        description="Sigla do Estado (UF). Ex: SC, SP"
    )
    
    @field_validator('zip_code')
    @classmethod
    def clean_zip_code(cls, v: str | None) -> str | None:
        if v is None: return v
        numeric_zip = re.sub(r'\D', '', v)
        
        if len(numeric_zip) != 8:
            raise ValueError('O CEP deve conter 8 dígitos.')
            
        return numeric_zip
    
    @field_validator('state')
    @classmethod
    def uppercase_state(cls, v: str | None) -> str | None:
        if v is None: return v
        return v.upper()


class UserAddressUpdate(UserAddressBase):
    
    pass

class UserAddressResponse(UserAddressBase):
    
    user_id: UUID
    model_config = ConfigDict(from_attributes=True)