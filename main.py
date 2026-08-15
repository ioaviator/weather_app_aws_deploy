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
    return templates.TemplateResponse(request, "index.html")


@app.get('/get_weather')
def get_weather_data(request:Request, state_1,state_2 = None,
                     state_3 = None):

  states = [state_1, state_2, state_3]
  
  # check for empty state names
  state_values = [value for value in states if value.strip()]

  if len(state_values) == 0:
    return {
      "message": "No state was given",
      "status": 200
    }
  
  weather_info = load_webpage(state_values)

  weather_data = {
    item["State"].capitalize(): {
        "Temperature": item["Temperature"],
        "Weather": item["Weather_Condition"],
        "Feels Like": item["Feels_Like"],
        "Humidity": item["Humidity"],
        "Dew Point": item["Dew_Point"]
    } for item in weather_info
  }
  
  return templates.TemplateResponse(request, "index.html", { "weather_data": weather_data })
