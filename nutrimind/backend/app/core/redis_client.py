from redis.asyncio import Redis
from app.core.config import settings

class RedisClient:
    def __init__(self):
        self.redis: Redis | None = None
    
    async def connect(self):
        self.redis = Redis.from_url(settings.REDIS_URL, decode_responses=True)
    
    async def disconnect(self):
        if self.redis:
            await self.redis.close()
    
    async def get(self, key: str):
        return await self.redis.get(key)
    
    async def set(self, key: str, value: str, ttl: int = None):
        if ttl:
            await self.redis.setex(key, ttl, value)
        else:
            await self.redis.set(key, value)
    
    async def delete(self, key: str):
        await self.redis.delete(key)
    
    async def publish(self, channel: str, message: str):
        await self.redis.publish(channel, message)
    
    async def subscribe(self, channel: str):
        pubsub = self.redis.pubsub()
        await pubsub.subscribe(channel)
        return pubsub

redis_client = RedisClient()