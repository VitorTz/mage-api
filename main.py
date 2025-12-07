from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from starlette.middleware.gzip import GZipMiddleware
from fastapi.middleware.cors import CORSMiddleware
from src.constants import Constants
from src.routes import auth
import contextlib


@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    print(f"[Starting {Constants.API_NAME}]")    

    print(f"[{Constants.API_NAME} STARTED]")

    yield

    print(f"[Shutting down {Constants.API_NAME}]")

    
app = FastAPI(    
    title=Constants.API_NAME, 
    description=Constants.API_DESCR,
    version=Constants.API_VERSION,
    lifespan=lifespan
)

app.mount("/static", StaticFiles(directory="static"), name="static")


if Constants.IS_PRODUCTION:
    origins = [
        "https://vitortz.github.io"
    ]
else:
    origins = [
        "http://localhost:5173"
    ]


app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.get("/favicon.ico")
async def favicon():
    return FileResponse("static/favicon/favicon.ico")


app.include_router(auth.router, prefix='/api/v1/auth', tags=['auth'])

########################## MIDDLEWARES ##########################

app.add_middleware(GZipMiddleware, minimum_size=1000)