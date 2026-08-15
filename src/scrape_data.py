import re
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.chrome.options import Options


def scrape_data(response, state:str):

  soup = BeautifulSoup(response, 'html.parser')

  # --- Extraction from <div id="qlook"> ---
  qlook_div = soup.find('div', id='qlook')

  # Extract temperature from <div class="h2">
  temperature = qlook_div.find('div', class_='h2').get_text(strip=True)

  # Extract weather condition from the first <p> tag
  weather_condition = qlook_div.find('p').get_text(strip=True)

  # Extract only the first text node from the second <p> tag (the "Feels Like" value)
  feels_like_p = qlook_div.find_all('p')[1]

  # Using .contents[0] gives the direct text before the <br> tag
  # e.g., "Feels Like: 39 °C"
  feels_like_text = feels_like_p.contents[0].strip()  

  # Remove the "Feels Like:" part from the string
  feels_like = feels_like_text.replace("Feels Like:", "").strip()

  
  table = soup.find('table', class_='table table--left table--inner-borders-rows')

  try:
    humidity_th = table.find('th', string=lambda text: text and 'Humidity:' in text)
    humidity = humidity_th.find_parent('tr').find('td').get_text(strip=True)
  except AttributeError:
    humidity = 'N/A'

  try:
    dew_point_th = table.find('th', string=lambda text: text and 'Dew Point:' in text)
    dew_point = dew_point_th.find_parent('tr').find('td').get_text(strip=True)
  except AttributeError:
    dew_point = 'N/A'

  ## clean data
  dew_point = re.sub(r"[^\d]", "", dew_point)
  temperature = re.sub(r"[^\d]", "", temperature) if temperature else "N/A"
  feels_like = re.sub(r"[^\d]", "", feels_like) if feels_like else "N/A"

  data:dict = {
    "State": state.title(),
    "Temperature": temperature,
    "Weather_Condition": weather_condition,
    "Feels_Like": feels_like,
    "Humidity": humidity,
    "Dew_Point": dew_point
  }

  return data


def load_webpage(states):
  weather_data = []

  # Set up headless Chrome options (optional: remove headless if you want to see the browser open)
  options = Options()
  options.add_argument("--headless=new")
  options.add_argument("--disable-gpu")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage") # Overcomes limited resource problems in containers

  options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) " \
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")

   # Initialize the Selenium WebDriver once
  driver = webdriver.Chrome(options=options)

  try:
    for state in states:
      state = state.lower().replace(" ", "-")
      url = f"https://www.timeanddate.com/weather/nigeria/{state}"
      
      driver.get(url)
      html_content = driver.page_source
      
      data = scrape_data(html_content, state)
      weather_data.append(data)

  finally:
    # Close the browser session only AFTER all states have been processed
    driver.quit()

  return weather_data
