import uvicorn
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from src.scrape_data import load_webpage

app = FastAPI()

templates = Jinja2Templates(directory="templates")
app.mount("/templates/static", StaticFiles(directory="templates/static"), name="static")


@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    return templates.TemplateResponse(request, "index.html", {"request": request})


@app.get('/get_weather')
def get_weather_data(request:Request):
  
  weather_info = load_webpage()

  return {
     "state": weather_info,
     "status": 200
  }




if __name__ == "__main__":
  uvicorn.run(app, host="127.0.0.1", port=8000)