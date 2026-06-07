from redis.asyncio import Redis
from redis.exceptions import ConnectionError, TimeoutError
import logging
from app.core.config import settings

logger = logging.getLogger(__name__)


class RedisClient:
    def __init__(self):
        self.redis: Redis | None = None
        self._connected = False

    async def connect(self):
        """Initialize Redis connection with error handling."""
        try:
            self.redis = Redis.from_url(settings.REDIS_URL, decode_responses=True)
            # Test the connection
            await self.redis.ping()
            self._connected = True
            logger.info("Redis connection established")
        except (ConnectionError, TimeoutError) as e:
            logger.warning(f"Redis connection failed: {e}. Caching will be disabled.")
            self.redis = None
            self._connected = False

    async def disconnect(self):
        if self.redis:
            await self.redis.close()
            self._connected = False

    async def get(self, key: str):
        """Get a value from Redis cache."""
        if not self._connected or not self.redis:
            return None
        try:
            return await self.redis.get(key)
        except (ConnectionError, TimeoutError) as e:
            logger.warning(f"Redis get failed: {e}")
            return None

    async def set(self, key: str, value: str, ttl: int = None):
        """Set a value in Redis cache."""
        if not self._connected or not self.redis:
            return False
        try:
            if ttl:
                await self.redis.setex(key, ttl, value)
            else:
                await self.redis.set(key, value)
            return True
        except (ConnectionError, TimeoutError) as e:
            logger.warning(f"Redis set failed: {e}")
            return False

    async def delete(self, key: str):
        """Delete a key from Redis cache."""
        if not self._connected or not self.redis:
            return False
        try:
            await self.redis.delete(key)
            return True
        except (ConnectionError, TimeoutError) as e:
            logger.warning(f"Redis delete failed: {e}")
            return False

    async def publish(self, channel: str, message: str):
        """Publish a message to a Redis channel."""
        if not self._connected or not self.redis:
            return False
        try:
            await self.redis.publish(channel, message)
            return True
        except (ConnectionError, TimeoutError) as e:
            logger.warning(f"Redis publish failed: {e}")
            return False

    async def subscribe(self, channel: str):
        """Subscribe to a Redis channel."""
        if not self._connected or not self.redis:
            return None
        try:
            pubsub = self.redis.pubsub()
            await pubsub.subscribe(channel)
            return pubsub
        except (ConnectionError, TimeoutError) as e:
            logger.warning(f"Redis subscribe failed: {e}")
            return None


redis_client = RedisClient()
