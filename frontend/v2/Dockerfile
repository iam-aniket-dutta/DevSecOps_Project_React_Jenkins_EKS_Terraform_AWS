FROM node:16-alpine

WORKDIR /app

ENV HOST=0.0.0.0
ENV PORT=3000
ENV CI=true

# Copy package specifications
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application source code
COPY . .

# Expose application port
EXPOSE 3000

# Start application directly
CMD ["npm", "start"]
